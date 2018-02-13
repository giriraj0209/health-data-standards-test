require 'test_helper'

class Cat1Test < Minitest::Test
  include HealthDataStandards::Export::Helper::Cat1ViewHelper

  def setup
    unless @initialized
      dump_database
      collection_fixtures('records')
      @patient = Record.where({first: "Barry"}).first

      pp = ProviderPerformance.new(start_date: Time.new(2012).to_i, end_date: Time.new(2012, 12, 31).to_i)
      provider = Provider.new(first: 'Hiram', last: 'McDaniels')
      provider.npi = '111111111'
      provider.save!
      pp.provider = provider
      @patient.provider_performances << pp

      @start_date = Time.now.years_ago(1)
      @end_date = Time.now

      collection_fixtures('health_data_standards_svs_value_sets', '_id', 'bundle_id')
      collection_fixtures('bundles', '_id')

      collection_fixtures('measures')
      @measures = HealthDataStandards::CQM::Measure.all
      @header = generate_header
      @qrda_xml = HealthDataStandards::Export::Cat1.new("r3").export(@patient, @measures, @start_date, @end_date, @header, "r3")
      @doc = Nokogiri::XML(@qrda_xml)
      @doc.root.add_namespace_definition('cda', 'urn:hl7-org:v3')
      @initialized = true
    end
  end

  def test_entries_for_data_criteria
    # for some reason the find method isn't working on @measures
    measure1 = @measures.select{|m| m.hqmf_id == '0001'}.first
    assert measure1
    data_criteria = measure1.all_data_criteria.find{|dc| dc.id == 'MedicationDispensedPreferredAsthmaTherapy_precondition_37'}
    puts "-------------"
    puts data_criteria.inspect
    puts "-------------"
    entries = entries_for_data_criteria(data_criteria, @patient)
    assert_equal 1, entries.length
    puts entries.inspect
    puts "-------------"
    assert_equal 'Multivitamin', entries[0].description
  end

  def generate_header
    header_hash=  {identifier: {root: "2.16.840.1.113883.4.6", extension: "header_ext"},
                   authors: [{ids: [ {root: "2.16.840.1.113883.4.7" , extension: "author_extension"}],
                              device: {name:"dvice_name" , model: "device_mod"},
                              addresses:[Address.new(street: ["1234 Drury Lane"], city: "Bedford", state: "MA", zip: "01960", country: "USA")],
			      telecoms: [Telecom.new(use: "WP", value: "555-555-1234")],
                              time: Time.now,
                              organization: {ids: [ {root: "2.16.840.1.113883.4.9" , extension: "authors_organization_ext"}],
                                             name: ""}}],
                   custodian: {ids: [ {root: "custodian_root" , extension: "custodian_ext"}],
                               person: {given: "", family: ""},
                               organization: {ids: [ {root: "2.16.840.1.113883.4.12" , extension: "custodian_organization_ext"}],
					      name: "", addresses:[Address.new(street: ["1234 Drury Lane"], city: "Bedford", state: "MA", zip: "01960", country: "USA")], telecoms: [Telecom.new(use: "WP", value: "555-555-3456")]}},
                   legal_authenticator:{ids: [ {root: "2.16.840.1.113883.4.14" , extension: "legal_authenticator_ext"}],
                                        addresses: [Address.new(street: ["1234 Drury Lane"], city: "Bedford", state: "MA", zip: "01960", country: "USA")],
					telecoms: [Telecom.new(use: "WP", value: "555-555-2345")],
                                        time: Time.now,
                                        person: {given:"hey", family: "there"},
                                        organization:{ids: [ {root: "2.16.840.1.113883.4.62" , extension: "legal_authenticator_org_ext"}],
                                                      name: ""}
                   }
    }

    Qrda::Header.new(header_hash)
  end
end
