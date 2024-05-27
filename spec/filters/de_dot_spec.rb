# encoding: utf-8
require 'spec_helper'
require "logstash/filters/de_dot"

describe LogStash::Filters::De_dot do
  let(:config) { { } }
  subject      { LogStash::Filters::De_dot.new(config) }

  let(:attrs) { { } }
  let(:event) { LogStash::Event.new(attrs) }

  before(:each) do
    subject.register
  end

  describe "Incorrect separator" do
    let(:special) { LogStash::Filters::De_dot.new({ "separator" => "." }) }
    it "should raise an exception if separator has a '.' in it" do
      expect { special.register }.to raise_error(ArgumentError)
    end
  end

  describe "Single field" do
    let(:attrs) { { "foo.bar" => "pass" } }

    it "should replace a dot with an underscore" do
      subject.filter(event)
      expect(event.to_hash.keys).not_to include('foo.bar')
      expect(event.get('foo_bar')).to eq('pass')
    end
  end

  describe "Single field with alternate separator" do
    let(:config) { { "separator" => "___" } }
    let(:attrs) { { "foo.bar" => "pass" } }

    it "should replace a dot with an underscore" do
      subject.filter(event)
      expect(event.to_hash.keys).not_to include('foo.bar')
      expect(event.get('foo___bar')).to eq('pass')
    end
  end

  describe "Multiple fields" do
    let(:attrs) { { "acme.roller.skates" => "coyote", "nodot" => "nochange" } }

    it "should replace all dots with underscores" do
      subject.filter(event)
      expect(event.to_hash.keys).not_to include('acme.roller.skates')
      expect(event.get('acme_roller_skates')).to eq('coyote')
    end

    it "should not change a field without dots" do
      subject.filter(event)
      expect(event.to_hash.keys).to include('nodot')
      expect(event.get('nodot')).to eq('nochange')
    end
  end

  describe "Multiple fields with underscores already" do
    let(:attrs) { { "acme_roller.skates" => "coyote", "no_dot" => "nochange" } }

    it "should replace all dots with underscores" do
      subject.filter(event)
      expect(event.to_hash.keys).not_to include('acme_roller.skates')
      expect(event.get('acme_roller_skates')).to eq('coyote')
    end

    it "should not change a field without dots" do
      subject.filter(event)
      expect(event.to_hash.keys).to include('no_dot')
      expect(event.get('no_dot')).to eq('nochange')
    end
  end

  describe "Nested fields" do
    let(:config) { { "nested" => true } }
    let(:attrs) { { "acme.roller.skates" => "coyote", "nodot" => "nochange" } }

    it "should convert dotted fields to sub-fields" do
      subject.filter(event)
      expect(event.to_hash.keys).not_to include('acme.roller.skates')
      expect(event.get('[acme][roller][skates]')).to eq('coyote')
    end

    it "should not change a field without dots" do
      subject.filter(event)
      expect(event.to_hash.keys).to include('nodot')
      expect(event.get('nodot')).to eq('nochange')
    end
  end

  describe "Specific nested field" do
    let(:config) { { "fields" => [ "[acme][roller.skates]" ] } }
    let(:attrs) { { "acme" => { "roller.skates" => "coyote" }, "foo.bar" => "nochange" } }

    it "should replace all dots with underscores within specified fields" do
      subject.filter(event)
      expect(event.get('acme')).not_to include('roller.skates')
      expect(event.get('[acme][roller_skates]')).to eq('coyote')
    end

    it "should not change a field not listed, even with dots" do
      subject.filter(event)
      expect(event.to_hash.keys).to include('foo.bar')
      expect(event.get('foo.bar')).to eq('nochange')
    end
  end

  describe "Multiple specific nested fields" do
    let(:config) {
      {
        "nested" => true,
        "fields" => [ "[acme][roller.skates]", "foo.bar", "[a.b][c.d][e.f]" ]
      }
    }
    let(:attrs) {
      {
        "acme" => { "roller.skates" => "coyote" },
        "foo.bar" => "nochange",
        "a.b" => { "c.d" => { "e.f" => "finally"} }
      }
    }

    it "should replace all dots with underscores within specified fields" do
      subject.filter(event)
      expect(event.get('acme')).not_to include('roller.skates')
      expect(event.get('[acme][roller][skates]')).to eq('coyote')
      expect(event.to_hash.keys).not_to include('foo.bar')
      expect(event.get('[foo][bar]')).to eq('nochange')
      expect(event.to_hash.keys).not_to include('a.b')
      expect(event.get('[a][b][c][d][e][f]')).to eq('finally')
    end
  end

  describe "Multiple specific nested fields with some not present" do
    let(:config) {
      {
        "nested" => true,
        "fields" => [ "[acme][roller.skates]", "foo.bar", "[a.b][c.d][e.f]" ]
      }
    }
    let(:attrs) {
      {
        "acme" => { "roller.skates" => "coyote" },
        "a.b" => { "c.d" => { "e.f" => "finally"} }
      }
    }

    it "should replace all dots with underscores within specified fields" do
      subject.filter(event)
      expect(event.get('acme')).not_to include('roller.skates')
      expect(event.get('[acme][roller][skates]')).to eq('coyote')
      expect(event.to_hash.keys).not_to include('a.b')
      expect(event.get('[a][b][c][d][e][f]')).to eq('finally')
    end

    it "should not add [foo][bar]" do
      subject.filter(event)
      expect(event.to_hash.keys).not_to include('foo.bar')
      expect(event.to_hash.keys).not_to include('foo')
    end
  end

  describe "Specific nested fields with underscores already" do
    let(:config) {
      {
        "fields" => [ "[acme][super.roller_skates]", "[field_with][no_dot]" ]
      }
    }
    let(:attrs) {
      {
        "acme" => { "super.roller_skates" => "coyote" },
        "field_with" => { "no_dot" => "nochange" }
      }
    }

    it "should replace all dots with underscores" do
      subject.filter(event)
      expect(event.get('acme')).not_to include('super.roller_skates')
      expect(event.get('[acme][super_roller_skates]')).to eq('coyote')
    end

    it "should not change a field without dots" do
      subject.filter(event)
      expect(event.to_hash.keys).to include('field_with')
      expect(event.get('[field_with][no_dot]')).to eq('nochange')
    end
  end

  describe "Further nesting specific nested fields with underscores already" do
    let(:config) {
      {
        "nested" => true,
        "fields" => [ "[acme][super.roller_skates]", "[field_with][no_dot]" ]
      }
    }
    let(:attrs) {
      {
        "acme" => { "super.roller_skates" => "coyote" },
        "field_with" => { "no_dot" => "nochange" }
      }
    }

    it "should replace all dots with underscores" do
      subject.filter(event)
      expect(event.get('acme')).not_to include('super.roller_skates')
      expect(event.get('[acme][super][roller_skates]')).to eq('coyote')
    end

    it "should not change a field without dots" do
      subject.filter(event)
      expect(event.to_hash.keys).to include('field_with')
      expect(event.get('[field_with][no_dot]')).to eq('nochange')
    end
  end

  describe "Field values containing false" do
    let(:config) {
      {
        "nested" => true,
      }
    }
    let(:attrs) {
      {
        "coyote.won" => false
      }
    }

    it "should not be ignored" do
      subject.filter(event)
      expect(event).not_to include('coyote.won')
      expect(event.get('[coyote][won]')).to be false
    end
  end

  describe "Recursive processing" do
    let(:config) { { "recursive" => true } }
    let(:attrs) { { "acme" => { "roller.skates" => "coyote", "nodot" => "nochange" } } }

    it "should replace dots in sub-fields to underscores" do
      subject.filter(event)
      expect(event.to_hash['acme'].keys).not_to include('roller.skates')
      expect(event.get('[acme][roller_skates]')).to eq('coyote')
    end

    it "should not change a field without dots" do
      subject.filter(event)
      expect(event.to_hash['acme'].keys).to include('nodot')
      expect(event.get('[acme][nodot]')).to eq('nochange')
    end

    context "with nested fields" do
      let(:config) { { "recursive" => true, "nested" => true } }
      let(:attrs) { { "acme" => { "roller.skates" => "coyote", "nodot" => "nochange" } } }

      it "should convert dotted sub-fields to nested sub-fields" do
        subject.filter(event)
        expect(event.to_hash['acme'].keys).not_to include('roller.skates')
        expect(event.get('[acme][roller][skates]')).to eq('coyote')
      end

      it "should not change a field without dots" do
        subject.filter(event)
        expect(event.to_hash['acme'].keys).to include('nodot')
        expect(event.get('[acme][nodot]')).to eq('nochange')
      end
    end

    context "with deeply nested fields" do
      let(:config) { { "recursive" => true, "nested" => true } }
      let(:attrs) { { "acme" => { "super.duper" => { "roller.skates" => "coyote", "nodot" => "nochange" } } } }

      it "should convert dotted sub-fields to nested sub-fields" do
        subject.filter(event)
        expect(event.to_hash['acme'].keys).not_to include('super.duper')
        expect(event.get('[acme][super][duper]').keys).not_to include('roller.skates')
        expect(event.get('[acme][super][duper][roller][skates]')).to eq('coyote')
      end

      it "should not change a field without dots" do
        subject.filter(event)
        expect(event.get('[acme][super][duper]').keys).to include('nodot')
        expect(event.get('[acme][super][duper][nodot]')).to eq('nochange')
      end
    end

    context "with specific nested fields" do
      let(:config) { { "recursive" => true, "nested" => true, "fields" => [ "acme" ] } }
      let(:attrs) { { "acme" => { "roller.skates" => "coyote" }, "foo.bar" => "nochange" } }

      it "should convert dotted sub-fields to nested sub-fields within specified fields" do
        subject.filter(event)
        expect(event.to_hash['acme'].keys).not_to include('roller.skates')
        expect(event.get('[acme][roller][skates]')).to eq('coyote')
      end

      it "should not change a field not listed, even with dots" do
        subject.filter(event)
        expect(event.to_hash.keys).to include('foo.bar')
        expect(event.get('foo.bar')).to eq('nochange')
      end
    end

    context "with multiple specific nested fields" do
      let(:config) {
        {
            "recursive" => true,
            "nested" => true,
            "fields" => [ "acme", "foo.bar", "a.b" ]
        }
      }
      let(:attrs) {
        {
            "acme" => { "roller.skates" => "coyote" },
            "foo.bar" => "nochange",
            "a.b" => { "c.d" => { "e.f" => "finally"} }
        }
      }

      it "should convert all dotted fields to sub-fields within specified fields" do
        subject.filter(event)
        expect(event.get('acme')).not_to include('roller.skates')
        expect(event.get('[acme][roller][skates]')).to eq('coyote')
        expect(event.to_hash.keys).not_to include('foo.bar')
        expect(event.get('[foo][bar]')).to eq('nochange')
        expect(event.to_hash.keys).not_to include('a.b')
        expect(event.get('[a][b][c][d][e][f]')).to eq('finally')
      end
    end
  end
end
