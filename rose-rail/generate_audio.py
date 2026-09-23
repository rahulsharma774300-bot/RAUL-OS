import math, os, wave, struct, random

SR=22050
OUT=os.path.join(os.path.dirname(__file__),"generated")
os.makedirs(OUT, exist_ok=True)

def save(name, samples):
    mx=max(1e-6,max(abs(x) for x in samples))
    gain=min(0.92/mx,1.0)
    with wave.open(os.path.join(OUT,name),"w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h",int(max(-1,min(1,s*gain))*32767)) for s in samples))

def env(t,d,a=.02,r=.12):
    if t<a: return t/a
    if t>d-r: return max(0,(d-t)/r)
    return 1.0

def tone(freq,dur,vol=.6,kind="sine",slide=0):
    n=int(SR*dur); out=[]
    phase=0.0
    for i in range(n):
        t=i/SR; f=freq+slide*t/dur
        phase+=2*math.pi*f/SR
        if kind=="square": v=1 if math.sin(phase)>=0 else -1
        elif kind=="saw": v=2*((phase/(2*math.pi))%1)-1
        else: v=math.sin(phase)
        out.append(v*vol*env(t,dur))
    return out

def noise_burst(dur,vol=.5,decay=10):
    return [(random.random()*2-1)*vol*math.exp(-decay*i/SR) for i in range(int(SR*dur))]

save("coin.wav",[a+b for a,b in zip(tone(900,.18,.55,"sine",700),tone(1800,.18,.20,"sine",500))])
save("jump.wav",tone(240,.32,.55,"sine",640))
save("swipe.wav",tone(170,.18,.35,"sine",250))
hit=noise_burst(.45,.75,8)
low=tone(82,.45,.7,"sine",-25)
save("hit.wav",[hit[i]+low[i] for i in range(min(len(hit),len(low)))])
save("power.wav",[a+b for a,b in zip(tone(360,.55,.45,"sine",900),tone(720,.55,.25,"sine",1200))])

# 8-second upbeat synth loop, 124 BPM-ish.
dur=8.0; n=int(SR*dur); music=[0.0]*n
beat=60/124
for i in range(n):
    t=i/SR
    # warm pad
    music[i]+=0.055*math.sin(2*math.pi*110*t)+0.035*math.sin(2*math.pi*220*t)
for b in range(int(dur/beat)+1):
    start=int(b*beat*SR)
    # kick every beat
    for j in range(min(int(.20*SR),n-start)):
        tt=j/SR
        f=95-55*(tt/.20)
        music[start+j]+=0.52*math.sin(2*math.pi*f*tt)*math.exp(-15*tt)
    # hat on offbeat
    hs=start+int(beat*.5*SR)
    if hs<n:
        for j in range(min(int(.06*SR),n-hs)):
            music[hs+j]+=(random.random()*2-1)*0.11*math.exp(-45*j/SR)
# bass pattern
notes=[55,65.41,73.42,65.41,55,82.41,73.42,65.41]
step=dur/len(notes)
for k,f in enumerate(notes):
    st=int(k*step*SR); ed=min(n,int((k+1)*step*SR))
    for i in range(st,ed):
        tt=(i-st)/SR
        music[i]+=0.12*math.sin(2*math.pi*f*tt)*(1-math.exp(-20*tt))*math.exp(-.5*tt)
save("music.wav",music)
print("generated audio in",OUT)
