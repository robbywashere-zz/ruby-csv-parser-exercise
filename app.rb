# File: app.rb

# WRITE YOUR CLASSES HERE

require 'date'
require 'csv'

class Date
  def to_s
    strftime('%-m/%-d/%Y')
  end
end

class City 

  CITY_CODES = {
    NYC: 'New York City',
    LA: 'Los Angeles',
    ATL: 'Atlanta'
  }

  CITY_NAMES = CITY_CODES.invert
  

  attr_reader :abbrv, :full

  def initialize(city)

    if CITY_CODES.key? city.to_sym
      @abbrv = city.to_s
      @full = CITY_CODES[city.to_sym]

    elsif CITY_NAMES.key? city.to_sym
      @abbrv = CITY_NAMES[city.to_sym].to_s
      @full = city.to_s
    else

      raise "Unknown city #{city}"
      
    end
    

  end

  def to_s
    @full
  end

  def ==(other)
    other.class == self.class && other.abbrv == abbrv
  end

  alias eql? ==

  def hash
    @abbrv.hash
  end

end

class Converter
  def self.date(strpformat)
    lambda do |field, _|
      begin 
        Date.strptime(field, strpformat)
      rescue
        field
      end
    end
  end

  def self.city
    lambda do |field, _| 
      begin 
        City.new field
      rescue
        field
      end
    end
  end

end

class Input 

  def self.from_comma_input(input)
    headers = %i[first_name city_name birth_date]
    converters = [Converter.date('%m/%d/%Y'), Converter.city]
    CSV.parse(input, col_sep: ', ', headers: headers, converters: converters)[0].to_h
  end


  def self.from_dollar_input(input)
    headers = %i[city_name birth_date last_name first_name]
    converters = [Converter.date('%m-%d-%Y'), Converter.city]
    CSV.parse(input, col_sep: ' $ ', headers: headers, converters: converters)[0].to_h
  end

end

class Person 

  attr_reader :first_name, :last_name, :birth_date, :city_name

  def initialize(first_name:, last_name: nil, birth_date:, city_name:)
    @first_name = first_name
    @last_name = last_name
    @birth_date = birth_date
    @city_name = city_name
  end


  def to_s
    [@first_name, @city_name, @birth_date].map(&:to_s).join(' ')
  end

end


class PeopleController
  def self.normalize(request_params)
    result = []
    %i[comma dollar].each do |type|
      request_params[type].each do |params|
        if request_params.key?(type)
          person = Person.new(**Input.send("from_#{type}_input", params))
          result << person.to_s
        end
      end
    end
    result
  end

end



describe PeopleController do
  let(:normalized_params) do 
    [
      'Mckayla Atlanta 5/29/1986',
      'Elliot New York City 4/3/1947',
      'Rhiannon Los Angeles 10/4/1974',
      'Rigoberto New York City 12/1/1962',
    ]
  end

  let(:input) do
    {
      comma: [
        'Mckayla, Atlanta, 5/29/1986',
        'Elliot, New York City, 4/3/1947',
      ],
      dollar: [
        'LA $ 10-4-1974 $ Nolan $ Rhiannon',
        'NYC $ 12-1-1962 $ Bruen $ Rigoberto',
      ]
    }
  end

  describe '#normalize' do
    it 'normalizes request parameters' do
      people = PeopleController.normalize input  
      expect(people).to match_array(normalized_params)
    end
  end
end

describe City do
  describe '#new' do
    it 'initializes with @abbrv and @full attributes' do
      city = City.new 'NYC'
      expect(city).to have_attributes(abbrv: 'NYC', full: 'New York City')
    end
  end
end

describe Person do
  it "outputs '<last_name> <city> <birthdate>'" do
    person = Person.new(first_name: 'Rhiannon', last_name: 'Nolan', city_name: "New York City", birth_date: "10/4/1974")
    expect(person.to_s).to eq('Rhiannon New York City 10/4/1974')
  end
end

describe Converter do
  describe '#date' do
    it 'converts a date string to Date object' do
      date = Converter.date('%m-%d-%Y').call('10-4-1974', nil)
      expect(date).to be_a(Date)
      expect(date).to have_attributes(month: 10, day: 4, year: 1974)
    end
  end

  describe '#city' do
    it 'converts a city abbreviation to a full city name string' do
      city = Converter.city().call('NYC', nil)
      expect(city.to_s).to eq('New York City')
    end
  end
end

describe Input do
  before do
    @date_attr = Date.new(1974, 10, 4)
    @city_attr = City.new 'NYC'
  end

  it 'initilizes from comma separated input' do
    person = Input.from_comma_input 'Mckayla, NYC, 10/4/1974'
    expect(person).to eq(first_name: 'Mckayla', city_name: @city_attr, birth_date: @date_attr)
  end

  it 'initilizes from dollar separated input' do
    person = Input.from_dollar_input 'NYC $ 10-4-1974 $ Nolan $ Rhiannon'
    expect(person).to eq(first_name: 'Rhiannon', last_name: 'Nolan', city_name: @city_attr, birth_date: @date_attr)
  end

end
