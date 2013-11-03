require 'spec_helper'
require 'ostruct'

describe PoroRepository do

  subject do
    PoroRepository.new("/tmp/test-poro-repository").tap do |repo|
      # disable storing of records in memory, so we know we're not cheating
      repo.remember = false
    end
  end

  let(:record) do
    OpenStruct.new.tap do |o|
      o.type = 'Invoice'
      o.blah = 'blah'
    end
  end

  let(:record_with_id) do
    OpenStruct.new.tap do |o|
      o.id = "123"
      o.type = 'Invoice'
      o.blah = 'blah'
    end
  end

  after(:each) do
    subject.nuke! 'yes, really'
  end

  context "when the record does not have an id attribute" do
    it "automatically assigns a random id" do
      record_id = subject.save_record record
      record_id.should match /^[a-f0-9]{40}$/
    end
  end

  context "when the record has an id attribute" do
    it "uses the record's id, not a random one" do
      record_id = subject.save_record record_with_id
      record_id.should == '123'
    end
  end

  it "saves and retrieves a record" do
    record_id = subject.save_record record
    loaded_record = subject.load_record('Invoice', record_id)
    loaded_record.should == record        # record should be the same value
    loaded_record.should_not equal record # but not the same object
                                          # NOTE - it would be the same object, but we did repo.remember = false
  end

  it "does not save more than one copy of a record" do
    record_id1 = subject.save_record record
    record_id2 = subject.save_record record
    record_id1.should == record_id2
  end

  # An Invoice has a Contact. We define the relationship as a boundary.
  # This means the Invoice and the Contact are stored separately. To
  # confirm this, we store the Invoice, and then try to load up just
  # the Contact.
  describe "boundaries" do

    subject do
      PoroRepository.new("/tmp/test-poro-repository").tap do |repo|
        repo.boundary :Invoice, :@contact
        repo.remember = false
      end
    end

    # Some arbitrary object that an invoice might have.
    # Here to test that it gets stored with the invoice and not
    # independently, since don't define a boundary for it.
    let(:terms) do
      TestObject.new.tap do |o|
        o.id = '123'
        o.type = 'Terms'
        o.due_days = 7
      end
    end

    let(:contact) do
      TestObject.new.tap do |o|
        o.id = '234'
        o.type = 'Contact'
        o.name = 'John Smith'
      end
    end

    let(:invoice) do
      TestObject.new.tap do |o|
        o.id = '345'
        o.type = 'Invoice'
        o.contact = contact
        o.terms = terms
      end
    end

    it "should not store non-boundary objects separately" do
      subject.save_record invoice
      loaded_terms = subject.load_record('Terms', terms.id)
      loaded_terms.should be_nil
    end

    it "should store boundary objects separately" do
      subject.save_record invoice
      loaded_contact = subject.load_record('Contact', contact.id)
      loaded_contact.should be_a contact.class
      loaded_contact.name.should == 'John Smith'
    end

    it "should load boundary objects" do
      subject.save_record invoice
      loaded_invoice = subject.load_record('Invoice', invoice.id)
      loaded_invoice.contact.should be_a contact.class
      loaded_invoice.contact.name.should == 'John Smith'
    end

  end

  describe "object lifecycle" do

    subject do
      PoroRepository.new("/tmp/test-poro-repository")
    end

    let(:invoice) do
      TestObject.new.tap do |o|
        o.id = '345'
        o.type = 'Invoice'
      end
    end

    context do
      before do
        subject.save_record invoice
      end

      it "should return the same object on sucessive calls to load_record" do
        record1 = subject.load_record 'Invoice', '345'
        record2 = subject.load_record 'Invoice', '345'
        record1.should equal record2
      end

      it "should return the original object if still in memory" do
        loaded_record = subject.load_record 'Invoice', '345'
        loaded_record.should equal invoice
      end
    end

    it "should not prevent records from being garbage collected" do
      GC.disable
      records = [TestObject.new.tap { |o| o.id = '345'; o.type = 'Invoice' }]
      subject.save_record records.first
      subject.send(:remembered_records).length.should == 1
      records.clear
      subject.send(:remembered_records).length.should == 1
      GC.enable
      GC.start
      subject.send(:remembered_records).length.should == 0
    end

  end

  describe "#load_all" do

    let(:object1) do
      TestObject.new.tap do |o|
        o.type = 'RecordType'
        o.some_field = 42
      end
    end

    let(:object2) do
      TestObject.new.tap do |o|
        o.type = 'RecordType'
        o.some_field = 43
      end
    end

    specify do
      object_id1 = subject.save_record object1
      object_id2 = subject.save_record object2
      all_records = subject.load_all('RecordType').sort_by(&:some_field)
      all_records.collect(&:some_field).should == [42, 43]
      all_records.collect do |r|
        subject.send(:id_from_record, r)
      end.should == [object_id1, object_id2]
    end
  end

  describe "#delete_record" do

    subject do
      PoroRepository.new("/tmp/test-poro-repository").tap do |repo|
        repo.boundary :Invoice, :@contact
      end
    end

    let(:contact) do
      TestObject.new.tap do |o|
        o.id = '234'
        o.type = 'Contact'
        o.name = 'John Smith'
      end
    end

    let(:invoice) do
      TestObject.new.tap do |o|
        o.id = '345'
        o.type = 'Invoice'
        o.contact = contact
      end
    end

    it "deletes the record, and not beyond boundary" do
      record_id = subject.save_record invoice
      subject.load_record('Invoice', record_id).should == invoice
      subject.delete_record(invoice)
      subject.load_record('Invoice', record_id).should be_nil
      subject.load_all('Contact').first.name.should == 'John Smith'
    end

  end

  describe "#pluck" do

    def new_repo_instance
      PoroRepository.new("/tmp/test-poro-repository").tap do |repo|
        repo.boundary :Invoice, :@contact
      end
    end

    subject do
      new_repo_instance
    end

    let(:contact) do
      TestObject.new.tap do |o|
        o.id = '234'
        o.type = 'Contact'
        o.name = 'John Smith'
      end
    end

    let(:invoice) do
      TestObject.new.tap do |o|
        o.id = '345'
        o.type = 'Invoice'
        o.contact = contact
      end
    end

    # note: will not work if the specified field is a boundary.
    it "extracts just the specified field" do
      record_id = subject.save_record invoice
      # Using a new instance of repo so we can call #previous_instantiated()
      # to confirm that the contact record wasn't loaded along with the invoice.
      # We must use a new repo instance to do this, since the contact record
      # is already in memory in the first repo instance since that instance was
      # used to save the Contact in the first place.
      repo = new_repo_instance
      repo.pluck('Invoice', :id).should == ['345']
      # it shouldn't instantiate boundary objects
      repo.send(:previous_instantiated, 'Contact', '234').should be_nil
      # it shouldn't remember the records it instantiated, since they will be
      # imcomplete without having loaded boundary objects.
      repo.send(:previous_instantiated, 'Invoice', '345').should be_nil
    end
  end

end