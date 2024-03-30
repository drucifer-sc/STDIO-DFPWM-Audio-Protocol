# STDIO DFPWM Audio Protocol

*Author: @TheDrucifer (Discord)*

*Version: 1.0*

*Last revised: 2024-03-30*

RFC 2119 keywords are used in this document to help reduce ambiguity, they are not capitalized as suggested in 2119.

## Quick information
| Information |                             |
| ----------- | --------------------------- |
| Version     | 1.0                         |
| Author      | @TheDrucifer (Discord)      |
| Type        | STDIO DFPWM Audio Protocol  |
| MIME        | `audio/sdap`                |

## Introduction
This standard serves to provide framework for unifying and informing the layout of transmissions of stereo DFPWM content on modem channels to increase access to the general public while preserving the hobbyist usage.

## Technical details
STDIO DFPWM Audio Protocol (SDAP) has two functional rulesets depending on the modem used:
| Modem Type | Transmission Mode |
| ---------- | ----------------- |
| Ender      | Full-Power        |
| Wireless   | Low-Power         |
| Wired      | Low-Power/Wired   |


#### Special note about Ender Modems
Ender Modems must only be used for Full-Power transmissions and are not intended for Low-Power use-case scenarios. SDAP transmissions from Ender Modems must always be treated as Full-Power broadcasts and conform to the standard drawn out below.

#### Transmission medium(s)
It is terribly important to note SDAP is not intended for and does not use Rednet. SDAP is a direct modem transmission protocol, this is both to reduce overhead, and avoid flooding the Rednet repeater channel with radio traffic. Be warned that broadcasting SDAP packets via Rednet on a public server may result in bad things happening! You have been warned. Always make sure you're using direct modem transmit calls, not Rednet!

### Packet and payload formatting
Common to all modes of transmission (Full/Low-Power & Wired, except where noted), modem transmissions should be sent to the assigned channel, using the modem transmit reply value as the PID value. The payload formatting shall be string.pack formatted as `s1s1s2`, given:
1. First string (max 255 characters): Contains the station callsign ("KDRU") immediately followed by the station's full printed name (e.g. "KDRU Drucifer's Private Reserves") and shall not be altered mid-operation (if you need to change this value, shut the station down first, then restart it with the new name in place).
2. Second string (max 255 characters) must contain the current program title (typically "Artist - Song") and may be altered on every packet transmitted.
3. Third string (max 65535 characters) contains the stereo DFPWM payload (should be 6000 bytes per channel, left channel first, for a total of 12000 bytes audio payload).

Example modem transmit snippet to give you an idea of where things go:
```lua
--If using 2 separate DFPWM files to deliver the complete Stereo transmission:
local sdapChan,sdapPID=65500,43210 --Set the channel and program ID numbers we will use
local channelName="Sample Channel" --Set the channel name to use (this must remain static during runtime)
local programName="Sample Program" --Set the program name to use (you may update this once per packet)
local sampleFiles={left=fs.open("left.dfpwm","rb"),right=fs.open("right.dfpwm","rb")} --Load files in binary mode to ensure data does not get mangled with unwanted UTF-8 conversion
local leftChannel,rightChannel=sampleFiles.left:readAll(),samplefiles.right:readAll() --Dump contents into string buffers
if #leftChannel>0 and #rightChannel>0 and #leftChannel==#rightChannel then
sampleFiles.left.close() sampleFiles.right.close() --Clean up our mess
end
for i=1,#leftChannel,6000 do
local leftSample,rightSample=leftChannel:sub(i,i+5999),rightChannel:sub(i,i+5999)
modem.transmit(sdapChan,sdapPID,string.pack("s1s1s2",channelName,programName,leftSample..rightSample))
sleep(1)
end
```

Example modem_message receiver snippet, minimum code required to receive and listen to broadcasts, though very poor overall in implementation
```lua
local listen,dfpwm={ch=65500,id=1000},require("cc.audio.dfpwm")
local decoders={left=dfpwm.make_decoder(),right=dfpwm.make_decoder()}
while not modem do --Find a wireless modem to listen with
for _,dev in ipairs({peripheral.find("modem")}) do
if dev.isWireless and dev.isWireless() then modem=dev end
end
end
modem.open(listen.ch)
while true do
local eventData={os.pullEvent("modem_message")}
if eventData[3]==listen.ch and eventData[4]==listen.id then
local unpack=string.unpack("s1s1s2",eventData[5])
local leftSample,rightSample=unpack[3]:sub(1,6000),unpack[3]:sub(6001,12000)
local leftAudio,rightAudio=decoders.left(leftSample),decoders.right(rightSample)
peripheral.call("left","playAudio",leftAudio)
peripheral.call("right","playAudio",rightAudio)
end
end
```

### Full-Power Transmissions (Ender Modem)
Full-Power transmitters must only use PIDs starting with 1000 and up (`1000-65535`) as PIDs `0-999` are reserved for Low-Power and Wired transmissions only (expected usage defined below). Full-Power SDAP is broadcast only on modem channels `65500-65531` (total `32` channels) with a maximum unique Program ID (PID) count of `32` per channel for a total of `1024` possible stations. Stations shall come online to the lowest channel number with an available PID allocation, using any available PID of their choice, and shall only begin using the next channel in sequence once all existing channels are at max capacity. Station allocations shall be first-come-first-serve to stations with long-term operational intentions (for short-term or hobbyist usage, See: Low-Power Transmissions), with an additional ask of limiting your individual (per player) maximum to 8 stations regardless of channel they eminate from. Station PIDs shall be considered abandoned and their allocation against the 32 station/PID cap removed, if not transmitted by their original broadcaster within the past 30 days. *WARNING: Duplicate PIDs may exist in the network provided they are on unique channels, always use a combination of channel and pid when tracking/tuning stations. (See: Shorthand formatting)*

### Low-Power Transmissions (Wireless Modem) [Special use cases]
Low-Power transmitters may use any channel, any PID, and any number of unique PIDs they wish except existing GPS/Rednet/other server channel restrictions. Additionally, Low-Power transmissions may use alternate formatting as defined by the transmitter's discretion. It is encouraged to continue to use the existing formatting to preserve compatibility when possible. Low-Power mode should be used for local-area wireless audio transmission for ambience/theming/announcements and other project/fork work to validate before submitting a PR.

### Wired Transmissions (Wired Modem)
Wired transmitters follow the same guidelines as Low-Power transmitters with regards to channels, PIDs, and formatting. Wired can be viewed as a closed-circuit extension or version of a Low-Power transmitter.

### Retransmission of Full-Power Transmissions
Retransmission of existing Full-Power stations may occur only to transfer the broadcast from Full-Power wireless, to a wired network for local closed circuit distribution. SDAP transmissions eminated on a Low-Power (or Wired) network should never be relayed or retransmitted to the Full-Power domain.

#### Shorthand formatting station channel and program ID numbers
Frequencies are suggested to be shorthanded as `channel:pid`, e.g. `65500:1337` is the shorthand frequency number for station `KDRU`, and `65500:1000` is the frequency for station `VVFM`.

#### Automatic station discovery
Automatic station discovery can be accomplished by listening for 3 seconds to all specified channels (65500-65531), and any other Low-Powered channels the user specifies, reading the received payload contents during that time using string.unpack with either "s1" formatting to capture just the station name, or "s1s1" to capture both the station name and current program name (preferred). Logging all reply channels with the relevant data to be presented to the user.
