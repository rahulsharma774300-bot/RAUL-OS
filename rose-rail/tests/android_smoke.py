"""Install and exercise the exported game on a real Android OS emulator."""
import subprocess,time,pathlib,re
out=pathlib.Path('android-evidence');out.mkdir(exist_ok=True)
def adb(*args):return subprocess.check_output(['adb',*map(str,args)],stderr=subprocess.STDOUT)
adb('install','-r','apk/Rose-Rail.apk')
adb('logcat','-c')
adb('shell','monkey','-p','com.raul.roserail','1')
time.sleep(12)
size=adb('shell','wm','size').decode(); w,h=map(int,re.findall(r'(\d+)x(\d+)',size)[-1])
def tap(x,y):adb('shell','input','tap',int(w*x),int(h*y))
def swipe(x,y,xx,yy):adb('shell','input','swipe',int(w*x),int(h*y),int(w*xx),int(h*yy),180)
def screen(name):(out/name).write_bytes(adb('exec-out','screencap','-p'))
screen('01-menu.png')
# The centered menu has its first button near 52% of viewport height.
tap(.5,.52);time.sleep(2)
screen('02-running.png')
swipe(.5,.65,.2,.65);swipe(.5,.65,.5,.35);time.sleep(.5)
swipe(.5,.4,.5,.75);swipe(.5,.65,.8,.65)
tap(.91,.08);time.sleep(1);screen('03-paused.png')
pid=adb('shell','pidof','com.raul.roserail').decode().strip()
assert pid,'Game process died after launch/input'
logs=adb('logcat','-d').decode(errors='replace');(out/'logcat.txt').write_text(logs)
assert not re.search(r'FATAL EXCEPTION|Fatal signal|SCRIPT ERROR|Parse Error',logs),'Android runtime error; inspect logcat'
(out/'result.txt').write_text('APK installed and launched; input sequence completed; process alive; no fatal or GDScript errors.\n')
print('ROSE_RAIL_ANDROID_OK')
