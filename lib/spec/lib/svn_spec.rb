# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'
require 'whimsy/asf'
require 'wunderbar'

describe ASF::SVN do
  
  # repo_entry should only include repos that have local workspaces
  
  describe "ASF::SVN.repo_entry" do
    it "should return string for 'templates'" do
      res = ASF::SVN.repo_entry('templates')
      expect(res.class).to equal(Hash)
    end

    it "should return nil for 'Bills'" do
      res = ASF::SVN.repo_entry('Bills')
      expect(res.class).to equal(NilClass)
    end

    it "should return nil for '__templates'" do
      res = ASF::SVN.repo_entry('__templates')
      expect(res.class).to equal(NilClass)
    end

  end

  describe "ASF::SVN.repo_entry!" do
    it "should return string for 'templates'" do
      res = ASF::SVN.repo_entry!('templates')
      expect(res.class).to equal(Hash)
    end

    it "should fail for '__templates'" do
      expect{
        ASF::SVN.repo_entry!('__templates')
      }.to raise_error(Exception)
    end

  end

  # svnurl should include aliases

  describe "ASF::SVN.svnurl" do
    it "should return URL for 'templates'" do
      res = ASF::SVN.svnurl('templates')
      expect(res.class).to equal(String)
      expect(res).to match(%r{https://.+/templates}) 
    end
  
    it "should return URL for 'Bills'" do
      res = ASF::SVN.svnurl('Bills')
      expect(res.class).to equal(String)
      expect(res).to match(%r{https://.+/Bills}) 
    end
  
    it "should return nil for '__templates'" do
      res = ASF::SVN.svnurl('__templates')
      expect(res.class).to equal(NilClass)
    end
  
  end

  describe "ASF::SVN.svnurl!" do
    it "should return URL for 'templates'" do
      res = ASF::SVN.svnurl!('templates')
      expect(res.class).to equal(String)
      expect(res).to match(%r{https://.+/templates}) 
    end
  
    it "should fail for '__templates'" do
      expect {
        ASF::SVN.svnurl!('__templates')
      }.to raise_error(Exception)
    end
  
  end

  # repo_entries should exclude aliases

  describe "ASF::SVN.repo_entries" do
    it "should return hash with templates but not Bills" do
      res = ASF::SVN.repo_entries
      expect(res.class).to equal(Hash)
      expect(res['templates'].class).to equal(Hash)
      expect(res['Bills']).to equal(nil)
    end
    
  end

  # find returns local workspace so excludes aliases

  describe "ASF::SVN.find" do
    it "should return string for 'templates'" do
      res = ASF::SVN.find('templates')
      expect(res.class).to equal(String)
    end
  
    it "should return nil for 'Bills'" do
      res = ASF::SVN.find('Bills')
      expect(res.class).to equal(NilClass)
    end
  
    it "should return nil for '__templates'" do
      res = ASF::SVN.find('__templates')
      expect(res.class).to equal(NilClass)
    end
  
  end

  describe "ASF:SVN.private_public" do
    it "should return an array of size 2" do
      res = ASF::SVN.private_public
      expect(res.size()).to equal(2)
      expect(res[0].size).to equal(15) # will need to be adjusted from time to time
      expect(res[1].size).to equal(11) # ditto.
    end
  end

  describe "ASF:SVN.getInfo(repo)" do
#    it "getInfo(public workspace) should return a string at least 30 chars long starting with 'Path: '" do
#      pub = ASF::SVN.private_public()[1]
#      repo = ASF::SVN[pub[1]] # select a public repo
#      out, err = ASF::SVN.getInfo(repo)
#      expect(err).to eq(nil)
#      expect(out.size).to be > 30
#      expect(out).to start_with("Path: ")
#    end

#    it "getInfo(private workspace) should return a string at least 30 chars long starting with 'Path: '" do
#      prv = ASF::SVN.private_public()[0]
#      repo = ASF::SVN[prv[1]] # select a private repo
#      out, err = ASF::SVN.getInfo(repo)
#      expect(err).to eq(nil)
#      expect(out.size).to be > 30
#      expect(out).to start_with("Path: ")
#    end

    it "getInfo(public url) should return a string at least 30 chars long starting with 'Path: '" do
      pub = ASF::SVN.private_public()[1]
      repo = ASF::SVN.svnurl(pub[1]) # select a public repo url
      expect(repo).to start_with("https://")
      out, err = ASF::SVN.getInfo(repo)
      expect(err).to eq(nil)
      expect(out.size).to be > 30
      expect(out).to start_with("Path: ")
    end

    it "getInfo(nil) should fail" do
      out, err = ASF::SVN.getInfo(nil)
      expect(out).to eq(nil)
      expect(err).to eq('path must not be nil')
    end

# How to ensure local SVN cached auth is not used?    
#    it "getInfo(private url) should return a string at least 30 chars long starting with 'Path: '" do
#      prv = ASF::SVN.private_public()[0]
#      repo = ASF::SVN.svnurl(prv[1]) # select a private repo
#      expect(repo).to start_with("https://")
#      out, err = ASF::SVN.getInfo(repo)
#      expect(err).to eq(nil)
#      expect(out.size).to be > 30
#      expect(out).to start_with("Path: ")
#    end

  end

  describe "ASF:SVN.getInfoItem" do
#    it "getInfoItem(public checkout,'url') should return the URL" do
#      pub = ASF::SVN.private_public()[1]
#      repo = ASF::SVN[pub[1]] # select a public repo
#      out, err = ASF::SVN.getInfoItem(repo,'url')
#      expect(err).to eq(nil)
#      expect(out).to eq(ASF::SVN.svnurl(pub[1]))
#    end

    it "getInfoItem(public url,'url') should return the URL" do
      pub = ASF::SVN.private_public()[1]
      repo = ASF::SVN.svnurl(pub[1]) # select a public repo URL
      out, err = ASF::SVN.getInfoItem(repo,'url')
      expect(err).to eq(nil)
      expect(out).to eq(ASF::SVN.svnurl(pub[1]))
    end
  end

  describe "ASF:SVN.list" do
#    it "list(public checkout,'url') should return a list" do
#      pub = ASF::SVN.private_public()[1]
#      repo = ASF::SVN[pub[1]] # select a public repo
#      out, err = ASF::SVN.list(repo)
#      expect(err).to eq(nil)
#      expect(out.size).to be > 10 # need a better test
#    end
  
    it "list(public url,'url') should return a list" do
      pub = ASF::SVN.private_public()[1]
      repo = ASF::SVN.svnurl(pub[1]) # select a public repo URL
      out, err = ASF::SVN.list(repo)
      expect(err).to eq(nil)
      expect(out.size).to be > 10 # need a better test
    end
  end

  describe "ASF:SVN.get" do
#    it "get(public checkout,'_template.xml') should return the revision and contents" do
#      repo = File.join(ASF::SVN['attic-xdocs'],'_template.xml')
#      revision, content = ASF::SVN.get(repo)
#      expect(revision).to match(/\d+/)
#      expect(content.size).to be > 1000 # need a better test
#    end
  
    it "get(public url,'_template.xml') should return the revision and contents" do
      repo = File.join(ASF::SVN.svnurl('attic-xdocs'),'_template.xml')
      revision, content = ASF::SVN.get(repo)
      expect(revision).to match(/\d+/)
      expect(content.size).to be > 1000 # need a better test
    end
    it "get(public url,'_____') should return 0 and nil" do
      repo = File.join(ASF::SVN.svnurl('attic-xdocs'),'_____')
      revision, content = ASF::SVN.get(repo)
      expect(revision).to eq('0')
      expect(content).to eq(nil)
    end
  end

  describe "ASF::SVN.passwordStdinOK?" do
    it "passwordStdinOK? should return true or false" do
      res = ASF::SVN.passwordStdinOK?
      expect(res).to be(true).or be(false)
    end
  end

  describe "ASF::SVN.svn" do
    it "svn('info', path) should return 'Name: path'" do
      repo = File.join(ASF::SVN.svnurl('attic-xdocs'),'_template.xml')
      out, err = ASF::SVN.svn('info',repo)
      expect(out).to match(/^Name: _template.xml$/)
    end
    it "svn('info', [path]) should return 'Name: path'" do
      repo = File.join(ASF::SVN.svnurl('attic-xdocs'),'_template.xml')
      out, err = ASF::SVN.svn('info',[repo])
      expect(out).to match(/^Name: _template.xml$/)
    end
    it "svn('info', [path1, path2], {args: ['--show-item','kind']}) should return 'file ...'" do
      path1 = File.join(ASF::SVN.svnurl('attic-xdocs'),'_template.xml')
      path2 = File.join(ASF::SVN.svnurl('attic-xdocs'),'jakarta.xml')
      out, err = ASF::SVN.svn('info',[path1, path2], {args: ['--show-item','kind']})
      expect(out).to match(/^file +https:/)
    end
  end
end