--Monitor SDAP frequencies and log them to screen with their callsign (designed for 3x3 monitor)
local os,peripheral,term,string,table=_G.os,_G.peripheral,_G.term,_G.string,_G.table
local running=true
local discoveryPool={}
local modem=peripheral.find("modem",function(n,dev)return dev.isWireless()end)
local w,h=term.getSize()
peripheral.find("monitor",function(n,dev)dev.clear()dev.setTextScale(0.5)end)
print("Wireless modem found:",peripheral.getName(modem))
local formatString="%11.11s | %s"
while running do
  w,h=term.getSize()
  for c=65500,65531 do
    local startTS=os.epoch("utc")
    modem.open(c) term.clear() term.setCursorPos(1,1)
    print("SDAP Broadcast Discovery List [Scanning: "..c.."]")
    repeat
      local packet={os.pullEvent()}
      if packet[1]=="modem_message" then
        for i=1,2 do table.remove(packet,1) end
        if packet[1]==c and packet[2]>=1000 and string.unpack("s1",packet[3]) then
          local stationName=string.unpack("s1",packet[3])
          if not discoveryPool[c] then
            discoveryPool[c]={[packet[2]]={stationName,os.epoch("utc")}}
          else
            discoveryPool[c][packet[2]]={stationName,os.epoch("utc")}
          end
        end
      else
        os.startTimer(0.05)
      end
      term.setCursorPos(1,2)
      print(string.format(formatString,"Frequency","Station Name"))
      for freq,pids in pairs(discoveryPool) do
        for pid,data in pairs(pids) do
          print(string.format(formatString,freq..":"..pid,data[1]))
        end
      end
      term.setCursorPos(1,h)
      term.write("https://github.com/drucifer-sc/STDIO-DFPWM-Audio-Protocol")
    until os.epoch("utc")>startTS+3000
    modem.close(c)
  end
end
