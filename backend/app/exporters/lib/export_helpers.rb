module ASpaceExport
  # Convenience methods that will work for resource
  # or archival_object models during serialization
  module ArchivalObjectDescriptionHelpers

    def archdesc_note_types
      %w(accruals appraisal arrangement bioghist accessrestrict legalstatus userestrict custodhist altformavail originalsloc fileplan odd acqinfo otherfindaid phystech prefercite processinfo relatedmaterial scopecontent separatedmaterial)
    end


    def did_note_types
      %w(abstract dimensions physdesc langmaterial physloc materialspec physfacet)
    end


    def bibliographies
      self.notes.select{|n| n['jsonmodel_type'] == 'note_bibliography'}
    end


    def indexes
      self.notes.select{|n| n['jsonmodel_type'] == 'note_index'}
    end


    def index_item_type_map
      {
        'corporate_entity'=> 'corpname',
        'genre_form'=> 'genreform',
        'name'=> 'name',
        'occupation'=> 'occupation',
        'person'=> 'persname',
        'subject'=> 'subject',
        'family'=> 'famname',
        'function'=> 'function',
        'geographic_name'=> 'geogname',
        'title'=> 'title'
      }
    end

    def controlaccess_linked_agents
      unless @controlaccess_linked_agents
        results = []
        linked = self.linked_agents || []
        linked.each_with_index do |link, i|

          role = link['relator'] ? link['relator'] : (link['role'] == 'source' ? 'fmo' : nil)

          agent = link['_resolved'].dup
          sort_name = agent['display_name']['sort_name']
          rules = agent['display_name']['rules']
          source = agent['display_name']['source']
          content = sort_name.dup

          if link['terms'].length > 0
            content << " -- "
            content << link['terms'].map{|t| t['term']}.join(' -- ')
          end

          node_name = case agent['agent_type']
                      when 'agent_person'; 'persname'
                      when 'agent_family'; 'famname'
                      when 'agent_corporate_entity'; 'corpname'
                      end

          atts = {}
          atts[:role] = role if role
          atts[:source] = source if source
          atts[:rules] = rules if rules

          results << {:node_name => node_name, :atts => atts, :content => content}
        end

        @controlaccess_linked_agents = results
      end

      @controlaccess_linked_agents
    end


    def controlaccess_subjects
      unless @controlaccess_subjects
        results = []
        linked = self.subjects || []
        linked.each do |link|
          subject = link['_resolved']

          node_name = case subject['terms'][0]['term_type']
                      when 'function'; 'function'
                      when 'genre_form', 'style_period';  'genreform'
                      when 'geographic', 'cultural_context'; 'geogname'
                      when 'occupation';  'occupation'
                      when 'topical'; 'subject'
                      when 'uniform_title'; 'title'
                      else; nil
                      end

          next unless node_name

          content = subject['terms'].map{|t| t['term']}.join(' -- ')

          atts = {}
          atts['source'] = subject['source'] if subject['source']

          results << {:node_name => node_name, :atts => atts, :content => content}
        end

        @controlaccess_subjects = results
      end

      @controlaccess_subjects
    end


    def archdesc_dates
      unless @archdesc_dates
        results = []
        dates = self.dates || []
        dates.each do |date|
          normal = ""
          unless date['begin'].nil?
            normal = "#{date['begin']}/"
            normal_suffix = (date['date_type'] == 'single' || date['end'].nil? || date['end'] == date['begin']) ? date['begin'] : date['end']
            normal += normal_suffix ? normal_suffix : ""
          end
          type = %w(single inclusive).include?(date['date_type']) ? 'inclusive' : 'bulk' 
          content = if date['expression']
                    date['expression']
                  elsif date['date_type'] == 'bulk'
                    'bulk'
                  elsif date['end'].nil? || date['end'] == date['begin']
                    date['begin']
                  else
                    "#{date['begin']}-#{date['end']}"
                  end

          atts = {:type => type}
          atts[:normal] = normal unless normal.empty?

          results << {:content => content, :atts => atts}
        end

        @archdesc_dates = results
      end

      @archdesc_dates
    end
  end


  module LazyChildEnumerations
    def children_indexes
      if @children.count > 0
        (0...@children.count)
      else
        []
      end
    end


    def get_child(index)
      subtree = @children[index]
      @child_class.new(subtree, @repo_id)
    end
  end


  module ExportModelHelpers

    def extract_date_string(date)
      if date['expression']
        date['expression']
      elsif date['end'].nil? || date['end'] == date['begin']
        date['begin']
      else
        "#{date['begin']} - #{date['end']}"
      end
    end


    def extract_note_content(note)
      if note['content']
        Array(note['content']).join(" ")
      else
        get_subnotes_by_type(note, 'note_text').map {|sn| sn['content']}.join(" ").gsub(/\n +/, "\n")
      end
    end


    def get_subnotes_by_type(obj, note_type)
      obj['subnotes'].select {|sn| sn['jsonmodel_type'] == note_type}
    end

  end
end
