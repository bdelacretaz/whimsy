#!/usr/bin/env ruby

#
# Server side router/controllers
#

ENV['LANG'] = 'en_US.UTF-8'

require 'whimsy/asf'

require 'mail'
require 'tmpdir'

require 'wunderbar/sinatra'
require 'wunderbar/bootstrap/theme'
require 'wunderbar/vue'
require 'wunderbar/underscore'
require 'wunderbar/markdown'
require 'wunderbar/jquery/stupidtable'
require 'ruby2js/filter/functions'
require 'ruby2js/filter/require'

require_relative 'models'

disable :logging # suppress log of requests to stderr/error.log

ASF::Mail.configure

helpers do
  def cssmtime
    File.mtime('public/stylesheets/app.css').to_i
  end
  def appmtime
    # TODO can this/should this be cached?
    Wunderbar::Asset.convert(File.join(settings.views, 'app.js.rb')).mtime.to_i
  end
end

get '/' do
  if env['REQUEST_URI'].end_with? '/'
    ASF::Person.preload(['asf-banned','loginShell']) # so can get inactive count
    @committers = ASF::Person.list
    @committees = ASF::Committee.pmcs
    @nonpmcs = ASF::Committee.nonpmcs
    @members = ASF::Member.list.keys - ASF::Member.status.keys # i.e. active member ids
    @groups = Group.list
    @podlings = ASF::Podling.to_h.values
    _html :index
  else
    redirect to('/')
  end
end

# Handle traditional top level PMCs
get '/committee/' do
  @members = ASF::Member.list.keys
  @committees = ASF::Committee.pmcs
  _html :committees
end

get '/committee/:name.json' do |name|
  data = Committee.serialize(name, env)
  pass unless data
  _json data
end

get '/committee/:name' do |name|
  @auth = Auth.info(env)
  @committee = Committee.serialize(name, env)
  pass unless @committee
  _html :committee
end

# Handle individual committer (or member) records
get '/committer/' do
  _html :committers
end

index = nil
index_time = nil
index_etag = nil
get '/committer/index.json' do
  # recompute index if the data is 5 minutes old or older
  index = nil if not index_time or Time.now-index_time >= 300

  if not index
    # bulk loading the mail information makes things go faster
    mail = Hash[ASF::Mail.list.group_by(&:last).
      map {|person, list| [person, list.map(&:first)]}]

    ASF::Person.preload(['id','name','mail','githubUsername'])
    # build a list of people, their public-names, and email addresses
    index = ASF::Person.list.sort_by(&:id).map {|person|
      result = {id: person.id, name: person.public_name, mail: mail[person], githubUsername: person.attrs['githubUsername'] || []}
      result[:member] = true if person.asf_member?
      result
    }.to_json

    # cache
    index_time = Time.now
    index_etag = etag = Digest::MD5.hexdigest(index)
  end

  # send response
  last_modified index_time
  etag index_etag
  content_type 'application/json', charset: 'UTF-8'
  expires [index_time+300, Time.now+60].max
  index
end


# Handle individual committer (or member) records
get '/committer2/' do
  @auth = Auth.info(env)
  # Restrict who can see this
  pass unless @auth[:member] or @auth[:chair]
  @notinavail = true
  _html :committers
end

index2 = nil
index2_time = nil
index2_etag = nil
get '/committer2/index.json' do
  @auth = Auth.info(env)
  # Restrict who can see this
  pass unless @auth[:member] or @auth[:chair]
  # recompute index if the data is 5 minutes old or older
  index2 = nil if not index2_time or Time.now-index2_time >= 300

  if not index2
    # bulk loading the mail information makes things go faster
    mail = Hash[ASF::Mail.list.group_by(&:last).
      map {|person, list| [person, list.map(&:first)]}]

    ASF::Person.preload(['id','name','mail','githubUsername'])
    # build a list of people, their public-names, and email addresses
    tmp = ASF::Person.list.sort_by(&:id).map {|person|
      result = {id: person.id, name: person.public_name, mail: mail[person], githubUsername: person.attrs['githubUsername'] || []}
      result[:member] = true if person.asf_member?
      result
    }

    ASF::ICLA.each {|icla|
      if icla.noId?
        iclaFile = ASF::ICLAFiles.match_claRef(icla.claRef)
        tmp << { name: icla.name, mail: icla.email, claRef: icla.claRef, iclaFile: iclaFile}
      end
    }
    index2 = tmp.to_json

    # cache
    index2_time = Time.now
    index2_etag = etag = Digest::MD5.hexdigest(index2)
  end

  # send response
  last_modified index2_time
  etag index2_etag
  content_type 'application/json', charset: 'UTF-8'
  expires [index2_time+300, Time.now+60].max
  index2
end


get '/committer/:name.json' do |name|
  data =  Committer.serialize(name, env)
  pass unless data
  _json data
end

# make __self__ an alias for one's own page
get '/committer/__self__' do
  redirect to("committer/#{env.user}")
end

get '/committer/:name' do |name|
  @auth = Auth.info(env)
  @committer = Committer.serialize(name, env)
  pass unless @committer
  _html :committer
end

post '/committer/:userid/:file' do |name, file|
  # Workround for handling arrays
  # if the key :array_prefix is defined, the value is assumed to be the prefix for
  # a list of values with the names: prefix1, prefix2 etc
  # All non-empty values are collected and stored in an array which is added to the
  # params with the key prefix
  prefix = params.delete(:array_prefix)
  if prefix
    array = []
    count = 1
    loop do
      key = prefix+count.to_s
      entry = params.delete(key)
      break unless entry # no key means end of sequence
      array << entry if entry.length > 0
      count += 1
    end
    params[prefix] = array
  end
  _json :"actions/#{params[:file]}"
end

get '/icla/' do
  @auth = Auth.info(env)
  # Restrict who can see this
  pass unless @auth[:member] or @auth[:chair]
  _html :iclas
end

icla_index = nil
icla_index_time = nil
icla_index_etag = nil
get '/icla/index.json' do
  @auth = Auth.info(env)
  # Restrict who can see this
  pass unless @auth[:member] or @auth[:chair]
  # recompute icla_index if the data is 5 minutes old or older
  icla_index = nil if not icla_index_time or Time.now-icla_index_time >= 300

  if not icla_index

    # build a list of ICLA Public names, email addresses and icla files
    tmp = []
    ASF::ICLA.each {|icla|
      if icla.noId?
        iclaFile = ASF::ICLAFiles.match_claRef(icla.claRef)
        tmp << { name: icla.name, mail: icla.email, claRef: icla.claRef, iclaFile: iclaFile}
      end
    }
    icla_index = tmp.to_json

    # cache
    icla_index_time = Time.now
    icla_index_etag = etag = Digest::MD5.hexdigest(icla_index)
  end

  # send response
  last_modified icla_index_time
  etag icla_index_etag
  content_type 'application/json', charset: 'UTF-8'
  expires [icla_index_time+300, Time.now+60].max
  icla_index
end

# Handle nonpmc: committees that aren't PMCs
get '/nonpmc/' do
  @members = ASF::Member.list.keys
  @nonpmcs = ASF::Committee.nonpmcs
  _html :nonpmcs
end

get '/nonpmc/:name.json' do |name|
  data = NonPMC.serialize(name, env)
  pass unless data
  _json data
end

get '/nonpmc/:name' do |name|
  @auth = Auth.info(env)
  @nonpmc = NonPMC.serialize(name, env)
  pass unless @nonpmc
  _html :nonpmc
end

# Handle groups: other kinds of auth/ldap/etc. groupings
get '/group/:name.json' do |name|
  _json Group.serialize(name)
end

get '/group/:name' do |name|
  @auth = Auth.info(env)
  @group = Group.serialize(name)
  pass unless @group and not @group.empty?
  _html :group
end

get '/group/' do
  @groups = Group.list
  _html :groups
end

# member list
get '/members' do
  _html :members
end

get '/members.json' do
  _json Hash[ASF.members.map {|person| [person.id, person.public_name]}.sort]
end

# Handle podling PPMCs
get '/ppmc/_new_' do
  @pmcsAndBoard = (ASF::Committee.pmcs.map(&:id) + ['board']).sort
  @officersAndMembers = (ASF.pmc_chairs + ASF.members).uniq.map(&:id)
  @ipmc = ASF::Committee['incubator'].owners.map(&:id)
  _html :ppmc_new
end

# active podling list
get '/ppmc/' do
  @projects = ASF::Project.list
  @ppmcs = ASF::Podling.list.select {|podling| podling.status == 'current'}
  _html :ppmcs
end

# individual podling info
get '/ppmc/:name.json' do |name|
  _json PPMC.serialize(name, env)
end

post '/ppmc/:name/establish' do |name|
  @name = name
  @chair = params[:chair] || env.user
  @description = params[:description]
  _text :'ppmc/establish'
end

get '/ppmc/:name' do |name|
  @auth = Auth.info(env)

  user = ASF::Person.find(env.user)
  @auth[:ipmc] = ASF::Committee.find('incubator').owners.include? user

  @ppmc = PPMC.serialize(name, env)
  pass unless @ppmc
  _html :ppmc
end

# complete podling list
get '/podlings' do
  attic = ASF::SVN['attic-xdocs']
  @attic = Dir[File.join(attic, '*.xml')].map {|file| File.basename(file, '.xml')}
  @committees = ASF::Committee.pmcs.map(&:id) # Use list of PMCs from CI.txt
  @podlings = ASF::Podling.list

  _html :podlings
end

# posted actions
post '/actions/:file' do
  _json :"actions/#{params[:file]}"
end

# attic issues
get '/attic/issues.json' do
  _json Attic.issues
end

# Handle overall organization chart
get '/orgchart/' do
  @org = OrgChart.load
  _html :orgchart
end

# Orgchart individual duties
get '/orgchart/:name' do |name|
  person = ASF::Person.find(env.user)

  unless person.asf_member? or ASF.pmc_chairs.include? person
    halt 401, "Not authorized\n"
  end

  @org = OrgChart.load
  @role = @org[name]
  @desc = OrgChart.desc
  pass unless @role

  @oversees = @org.select do |role, duties|
    duties['info']['reports-to'].split(/[, ]+/).include? name
  end

  _html :duties
end

# for debugging purposes
get '/env' do
  content_type 'text/plain'

  asset = {
    path: Wunderbar::Asset.path,
    root: Wunderbar::Asset.root,
    virtual: Wunderbar::Asset.virtual,
    scripts: Wunderbar::Asset.scripts.map {|script|
      source = script.options[:file]
      {
        path: script.path, 
        source: source,
        mtime: source && File.mtime(source),
        size: source && File.size(source),
      }
    },
    stylesheets: Wunderbar::Asset.stylesheets.map {|stylesheet|
      source = stylesheet.options[:file]
      {
        path: stylesheet.path, 
        source: source,
        mtime: source && File.mtime(source),
        size: source && File.size(source),
      }
    },
  }

  JSON.pretty_generate(env: env, ENV: ENV.to_h, asset: asset)
end

# Handle error and other conditions
not_found do
  @errors = env
  _html :not_found
end

error do
  @errors = env
  _html :errors
end

# Redirect common partial paths
['/committee', '/committer', '/group', '/nonpmc', '/ppmc', '/orgchart'].each do |ppath|
  get ppath do
    redirect to("#{ppath}/")
  end
end
get '/orgchart.cgi' do
  redirect to('/orgchart/')
end
