#!/usr/bin/env ruby
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery/stupidtable'
require 'net/http'

PAGETITLE = 'Apache TLP Website Link Checks'
cols = %w( events foundation license sponsorship security thanks )
DATAURI = 'http://intertwingly.net/tmp/site-check.json'

_html do
  _body? do
    _style %{
      .table td {font-size: smaller;}
    }
    _whimsy_header PAGETITLE
    _whimsy_content do
      _div.panel.panel_default do
        _div!.panel_heading 'Common Links Found On TLP Sites'
        _div.panel_body do
          _ 'Current (beta) status of Apache PMC top level websites vis-a-vis '
          _a! 'required links', href: 'https://www.apache.org/foundation/marks/pmcs#navigation'
          _ ', generated statically.'
          _a! 'See crawler code', href: 'https://whimsy.apache.org/tools/site-check.rb'
          _ ', and '
          _a! 'raw JSON data.', href: DATAURI  
        end
        _table.table.table_condensed.table_striped do
          _thead do  
            _tr do
              _th! 'Project', data_sort: 'string'
              cols.each do |c|
                _th! c.capitalize, data_sort: 'string'
              end
            end
          end
          sites = JSON.parse(Net::HTTP.get(URI(DATAURI)))
          _tbody do
            sites.each do |n, links|
              _tr do
                _td do 
                  _a! "#{links['display_name']}", href: links['uri']
                end
                cols.each do |c|
                  links[c] ? _td!(links[c].sub(/https?:\/\//, '').sub(/(www\.)?apache\.org/i, 'a.o')) : _td!('')
                end
              end
            end
          end
        end
      end
    end      
    _script %{
      var table = $(".table").stupidtable();
      table.on("aftertablesort", function (event, data) {
        var th = $(this).find("th");
        th.find(".arrow").remove();
        var dir = $.fn.stupidtable.dir;
        var arrow = data.direction === dir.ASC ? "&uarr;" : "&darr;";
        th.eq(data.column).append('<span class="arrow">' + arrow +'</span>');
      });
    }
    _whimsy_footer({
      "https://www.apache.org/foundation/marks/pmcs" => "Apache Project Branding Policy",
      "https://www.apache.org/foundation/marks/resources" => "Trademark Site Map",
      "https://www.apache.org/foundation/marks/list/" => "Official Apache Trademark List"
    })
  end
end