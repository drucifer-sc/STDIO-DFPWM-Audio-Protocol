--Broadcast receiver
--A much more fleshed out receiver for SDAP; Usage: receiver[.lua] <PID:1000-65535> <FREQ:65500-65531>
--Keyboard inputs: +/- (PID stepping), PgUp/PgDn (PID Seek), L (list discovered stations and relevant data), R (resets playback)
settings.define("cc.drucifer.sdap.receiver.speaker.left",{description="Provide the name of the left speaker",type="string",default="left"})
settings.define("cc.drucifer.sdap.receiver.speaker.right",{description="Provide the name of the right speaker",type="string",default="right"})
local os,term,peripheral,math=_G.os,_G.term,_G.peripheral,_G.math --Down With Global Facism, Join The Local Revolution
local args={...}
local modem=peripheral.find("modem",function(n,dev)return dev.isWireless()end)
print("Wireless modem found:",peripheral.getName(modem))
local frequency=65500
local pid=0
local dfpwm=require("cc.audio.dfpwm")
local ldec,rdec=dfpwm.make_decoder(),dfpwm.make_decoder()
if not args[1] then print("No Program ID (PID) provided to tune!") return end
if 0+args[1] >= 1000 and 0+args[1] <= 65535 then pid=0+args[1] end
if args[2] then
  if 0+args[2]>=65500 and 0+args[2]<=65531 then
    frequency=0+args[2]
  else
    print("Frequency out of spec (65500-65531)") return
  end
end
modem.open(frequency)

local running,startup=true,true
local fastSwitchBuffer,programData={},{}
local speakerLeft,speakerRight=settings.get("cc.drucifer.sdap.receiver.speaker.left"),settings.get("cc.drucifer.sdap.receiver.speaker.right")

local function fastSwitcher()
  print("Changed program ID",pid)
  print(programData[pid] and programData[pid][1].." | "..programData[pid][2] or "")
  ldec,rdec=dfpwm.make_decoder(),dfpwm.make_decoder()
  _,_=peripheral.call(speakerLeft,"stop"),peripheral.call(speakerRight,"stop")
  if fastSwitchBuffer[pid] then
    lbuf,rbuf=ldec(fastSwitchBuffer[pid]:sub(1,6000)),rdec(fastSwitchBuffer[pid]:sub(6001,12000))
    _,_=peripheral.call(speakerLeft,"playAudio",lbuf),peripheral.call(speakerRight,"playAudio",rbuf)
    fastSwitchBuffer[pid]=nil
  end
end

local lbuf,rbuf,speakerWaiting,packetBuffer="","",{},{}

local function handleModem()
  while running do
    local packet={os.pullEvent()}
    if packet[1]=="modem_message" then --Handle modem!
      if packet[3]==frequency and packet[4]==pid then
        table.insert(packetBuffer,packet[5])
        if not programData[packet[4]] then programData[packet[4]]={"",""} end
        if startup then speakerWaiting={"init"} os.queueEvent("speaker_audio_empty","init") end
      elseif packet[3]==frequency then
        if not programData[packet[4]] then programData[packet[4]]={"",""} end
        local unpacket={string.unpack("s1s1s2",packet[5])}
        for p=1,2 do if unpacket[p]~=programData[packet[4]][p] then programData[packet[4]][p]=unpacket[p] end end
        fastSwitchBuffer[packet[4]]=unpacket[3]
      end
    end
  end
end

local function handlePlayback()
  while running do
    local packet={os.pullEvent()}
    if packet[1]=="speaker_audio_empty" then --Handle audio playback completion
      if #speakerWaiting>0 or startup then
        for i,name in ipairs(speakerWaiting) do
          if name == packet[2] then table.remove(speakerWaiting,i) end
        end
        if #speakerWaiting==0 or startup then --Pull and play the next sample from buffer
          while #packetBuffer<1 do --If no packets in buffer, wait
            sleep()
          end
          startup=false
          local programChange=false
          lbuf,rbuf="",""
          local unpacket={string.unpack("s1s1s2",packetBuffer[1])} table.remove(packetBuffer,1)
          for p=1,2 do if unpacket[p]~=programData[pid][p] then programData[pid][p]=unpacket[p] programChange=true end end
          lbuf,rbuf=ldec(unpacket[3]:sub(1,6000)),rdec(unpacket[3]:sub(6001,12000))
          _,_=peripheral.call(speakerLeft,"playAudio",lbuf),peripheral.call(speakerRight,"playAudio",rbuf)
          speakerWaiting={speakerRight,speakerLeft}
          if programChange then term.clear() term.setCursorPos(1,1) print(programData[pid][1],"|",programData[pid][2]) end
        end
      end
    end
  end
end

while running do
  parallel.waitForAny(handleModem,handlePlayback,function()
    while running do
      local packet={os.pullEvent()}
      if packet[1]=="key" then
        local keypress=packet[2]
        if keypress==keys.q then --Quit
          peripheral.call(speakerLeft,"stop")
          peripheral.call(speakerRight,"stop")
          print("Quit")
          running=false
          break
        end
        if keypress==keys.numPadAdd then --Sequentially seek PIDs
          pid=math.min(math.max(pid+1,1000),65535)
          packetBuffer={} --Dump and reset packet buffer
          if programData[pid] then fastSwitcher() end
        end
        if keypress==keys.numPadSubtract then
          pid=math.min(math.max(pid-1,1000),65535)
          packetBuffer={} --Dump and reset packet buffer
          if programData[pid] then fastSwitcher() end
        end
        if keypress==keys.l then --List available channels
          print("Program list:")
          for id,prog in pairs(programData) do
            print("PID:"..id,prog[1],"|",prog[2])
          end
        end
        if keypress==keys.r and #lbuf>0 and #rbuf>0 then --Reset playback buffer
          _,_=peripheral.call(speakerLeft,"stop"),peripheral.call(speakerRight,"stop")
          _,_=peripheral.call(speakerLeft,"playAudio",lbuf),peripheral.call(speakerRight,"playAudio",rbuf)
          speakerWaiting={speakerRight,speakerLeft} --Reset speaker waiting queue
        end
        if keypress==keys.pageUp then --Seek to next available PID
          term.write("Seek+ ")
          local oldPID=pid
          for i=pid+1,65535 do
            if programData[i] then pid=i break end
          end
          packetBuffer={} --Dump and reset packet buffer
          if pid~=oldPID then fastSwitcher() end
        end
        if keypress==keys.pageDown then --Seek to prev available PID
          term.write("Seek- ")
          local oldPID=pid
          for i=pid-1,1000,-1 do
            if programData[i] then pid=i break end
          end
          packetBuffer={} --Dump and reset packet buffer
          if pid~=oldPID then fastSwitcher() end
        end
      end
    end
  end)
end
