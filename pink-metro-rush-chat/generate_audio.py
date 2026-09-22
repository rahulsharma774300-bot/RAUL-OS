import math, os, wave, struct, random
SR=22050
OUT=os.path.join(os.path.dirname(__file__),"generated")
os.makedirs(OUT,exist_ok=True)
random.seed(774300)

def save(name,samples):
    peak=max(1e-6,max(abs(x) for x in samples))
    gain=min(.92/peak,1.0)
    with wave.open(os.path.join(OUT,name),"w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        frames=bytearray()
        for s in samples:
            v=int(max(-1,min(1,s*gain))*32767)
            frames.extend(struct.pack("<h",v))
        w.writeframes(bytes(frames))

def env(t,d,a=.008,r=.08):
    if t<a:return t/a
    if t>d-r:return max(0,(d-t)/r)
    return 1.0

def tone(freq,dur,vol=.5,slide=0,kind="sine"):
    n=int(SR*dur); out=[]; phase=0
    for i in range(n):
        t=i/SR; f=max(25,freq+slide*(t/dur))
        phase += 2*math.pi*f/SR
        if kind=="square": x=1 if math.sin(phase)>=0 else -1
        elif kind=="saw": x=2*((phase/(2*math.pi))%1)-1
        else:x=math.sin(phase)
        out.append(x*vol*env(t,dur))
    return out

def mix(*tracks):
    n=max(map(len,tracks)); out=[0.0]*n
    for tr in tracks:
        for i,v in enumerate(tr):out[i]+=v
    return out

def noise(dur,vol=.4,decay=8):
    return [(random.random()*2-1)*vol*math.exp(-decay*i/SR) for i in range(int(dur*SR))]

save("coin.wav",mix(tone(1050,.16,.55,650),tone(2100,.16,.22,800)))
save("jump.wav",mix(tone(270,.28,.46,720),tone(540,.28,.18,900)))
save("slide.wav",mix(noise(.22,.30,16),tone(150,.22,.22,-65)))
save("lane.wav",tone(225,.12,.28,310))
save("hit.wav",mix(noise(.45,.68,7),tone(80,.45,.62,-30)))
save("power.wav",mix(tone(330,.62,.38,1200),tone(660,.62,.22,1600)))
save("revive.wav",mix(tone(420,.75,.33,1500),tone(840,.75,.24,2100)))
save("train_horn.wav",mix(tone(220,.65,.42,-20),tone(330,.65,.24,-30)))

# 16s bright arcade rail-runner loop
dur=16.0; n=int(SR*dur); out=[0.0]*n
bpm=132; beat=60/bpm
# pad
for i in range(n):
    t=i/SR
    out[i]+=0.035*math.sin(2*math.pi*110*t)+0.022*math.sin(2*math.pi*220*t)
# percussion
for b in range(int(dur/beat)+1):
    st=int(b*beat*SR)
    for j in range(min(int(.16*SR),max(0,n-st))):
        tt=j/SR
        f=105-62*(tt/.16)
        out[st+j]+=0.48*math.sin(2*math.pi*f*tt)*math.exp(-18*tt)
    # clap beats 2/4
    if b%2==1:
        cs=st
        for j in range(min(int(.11*SR),max(0,n-cs))):
            out[cs+j]+=(random.random()*2-1)*.14*math.exp(-32*j/SR)
    # hats
    for sub in [0.5,0.75]:
        hs=st+int(beat*sub*SR)
        if hs<n:
            for j in range(min(int(.04*SR),n-hs)):
                out[hs+j]+=(random.random()*2-1)*.07*math.exp(-60*j/SR)

# bass
bass=[55,55,65.41,73.42,55,82.41,73.42,65.41]*2
step=dur/len(bass)
for k,f in enumerate(bass):
    st=int(k*step*SR); ed=min(n,int((k+1)*step*SR))
    for i in range(st,ed):
        tt=(i-st)/SR
        out[i]+=0.11*math.sin(2*math.pi*f*tt)*math.exp(-.32*tt)

# candy lead arpeggio
scale=[440,523.25,659.25,783.99,659.25,523.25,493.88,587.33]
note=beat/2
for k in range(int(dur/note)):
    f=scale[k%len(scale)]*(1 if (k//16)%2==0 else 1.12246)
    st=int(k*note*SR); ed=min(n,st+int(note*.82*SR))
    for i in range(st,ed):
        tt=(i-st)/SR
        amp=.055*(1-math.exp(-30*tt))*math.exp(-2.8*tt)
        out[i]+=amp*math.sin(2*math.pi*f*tt)+amp*.25*math.sin(2*math.pi*f*2*tt)

save("music.wav",out)
print("audio generated",OUT)
