# kayakocleaner
require 'rubygems'
require 'mechanize'

STDOUT.sync = true

@kayako_admin_url = ARGV[0]
@username = ARGV[1]
@password = ARGV[2]

class Ticket
  attr_reader :name, :search_term, :disposal
  def initialize(name, search_term, disposal)
    @name = name
    @search_term = search_term
    @disposal = disposal # will be :close or :delete
  end

  def mass_action_radio_button
    case @disposal
    when :close
      0
    when :delete
      3
    end
  end
end

# Define the tickets we want to clear out as an array of Ticket objects
@tickets_to_clear = [
  Ticket.new("nagios alert", "alert - ", :delete),
  Ticket.new("status warning", "status warning from ", :delete),
  Ticket.new("ensim backup", "backup notification for ", :delete),
  Ticket.new("cpanel backup", "[cpbackup] backup complete on ", :delete),
  Ticket.new("site usage summary", "site usage summary of ", :delete),
  Ticket.new("EMC alert", "EMC monitoring alert", :delete),
  Ticket.new("bounced mail", "returned mail: see transcript fore details", :delete)
]

a = Mechanize.new
# Log in
login_page = a.get(@kayako_admin_url)
login_form = login_page.forms[0]
login_form.fields[0].value = @username
login_form.fields[1].value = @password
dashboard_page = a.submit(login_form, login_form.buttons.first)
# If login failed, we just get the login page again
if dashboard_page.title !~ /.*Home$/
  puts "Unable to log in."
  exit
end

# Navigate to the 'Manage' page, in list view
manage_page = a.get(@kayako_admin_url + '?_a=maintickets&_m=view&listview=1')

# Search for the tickets we don't want
@tickets_to_clear.each do |ticket|
  print "Searching for #{ticket.name} tickets to clear..."
  search_form = manage_page.forms[1]
  search_form.field_with(:name => 'search_query').value = ticket.search_term
  search_form.field_with(:name => 'sort_results').value = 500 # pick a suitable number of results
  results_page = a.submit(search_form, search_form.buttons.first)
  # Report how many tickets we found of this ticket type
  checkboxes = results_page.search('//input[starts-with(@name, "cb")]')
  puts " found #{checkboxes.length} tickets."

  # Fill in the mass action form now with our relevant disposal method
  mass_action_form = results_page.forms[2]
  # Tick the relevant radio button for closing or deleting
  mass_action_form.radiobuttons_with(:name => 'm_type')[ticket.mass_action_radio_button].check
  if checkboxes.length > 0
    # Loop through our results, ticking checkboxes
    mass_action_form.checkboxes.each do |checkbox|
      if checkbox.name =~ /cb[0-9]{6}/ # all the ticket checkboxes have this format
        checkbox.check
      end
    end
    print "#{ticket.disposal.to_s.capitalize.chop}ing #{checkboxes.length} #{ticket.name} tickets... "
    a.submit(mass_action_form, mass_action_form.buttons.first)
    puts "done!"
  end
end
