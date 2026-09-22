package com.raul.neonpanther;

import android.app.Activity;
import android.os.Bundle;
import android.os.Build;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.content.Context;
import android.graphics.*;
import android.view.*;
import java.util.*;

public class MainActivity extends Activity {
    @Override public void onCreate(Bundle b) {
        super.onCreate(b);
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN, WindowManager.LayoutParams.FLAG_FULLSCREEN);
        getWindow().getDecorView().setSystemUiVisibility(
            View.SYSTEM_UI_FLAG_FULLSCREEN |
            View.SYSTEM_UI_FLAG_HIDE_NAVIGATION |
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY |
            View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN |
            View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION |
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        );
        setContentView(new Game(this));
    }

    public static class Game extends View {
        private final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Random r = new Random();
        private final ArrayList<Obj> objects = new ArrayList<>();
        private final ArrayList<Particle> particles = new ArrayList<>();

        private float w,h,ground;
        private float px,py,vy,vx;
        private float speed=520f, spawn=0f, shake=0f, flash=0f, slow=0f;
        private int score=0, coins=0, combo=1, lives=3;
        private boolean started=false, over=false;
        private long last=System.nanoTime();
        private float downX,downY;

        static class Obj {
            float x,y,rad;
            int type;
            Obj(float x,float y,float rad,int type){this.x=x;this.y=y;this.rad=rad;this.type=type;}
        }
        static class Particle {
            float x,y,vx,vy,life,size;
            Particle(float x,float y,float vx,float vy,float life,float size){
                this.x=x;this.y=y;this.vx=vx;this.vy=vy;this.life=life;this.size=size;
            }
        }

        Game(Context c){
            super(c);
            p.setTypeface(Typeface.create("sans-serif-black", Typeface.BOLD));
            setBackgroundColor(Color.BLACK);
        }

        @Override protected void onSizeChanged(int W,int H,int oldW,int oldH){
            w=W; h=H; ground=h*.82f; reset();
        }

        private void reset(){
            px=w*.24f; py=ground-64; vy=0; vx=0;
            speed=520; spawn=.2f; shake=0; flash=0; slow=0;
            score=0; coins=0; combo=1; lives=3;
            started=false; over=false;
            objects.clear(); particles.clear();
            last=System.nanoTime();
        }

        @Override protected void onDraw(Canvas c){
            long now=System.nanoTime();
            float dt=Math.min(.035f,(now-last)/1_000_000_000f);
            last=now;
            if(started && !over) update(dt);
            drawWorld(c);
            postInvalidateOnAnimation();
        }

        private void update(float dt){
            if(slow>0){ slow-=dt; dt*=.45f; }
            speed += 8f*dt;
            score += (int)(75f*dt*combo);

            vy += 2050f*dt;
            py += vy*dt;
            px += vx*dt;
            if(py>ground-64){ py=ground-64; vy=0; }
            px=Math.max(48,Math.min(w-48,px));

            spawn-=dt;
            if(spawn<=0){
                spawn=Math.max(.34f,.90f-(speed-520f)/1600f);
                spawnObject();
            }

            for(int i=objects.size()-1;i>=0;i--){
                Obj o=objects.get(i);
                o.x -= speed*dt*(o.type==3?1.35f:1f);
                if(o.x<-100){ objects.remove(i); continue; }

                float dx=o.x-px, dy=o.y-py;
                float rr=o.rad+34;
                if(dx*dx+dy*dy < rr*rr){
                    if(o.type==0){
                        coins++; score+=120*combo; combo=Math.min(9,combo+1);
                        burst(o.x,o.y,16,0xffffd54a); flash=.12f;
                    } else if(o.type==2){
                        slow=3.2f; score+=450; combo=Math.min(9,combo+2);
                        burst(o.x,o.y,24,0xff4de8ff); flash=.18f; vibrate(40);
                    } else if(o.type==3){
                        score+=700; combo=9; burst(o.x,o.y,30,0xffb65cff); flash=.22f; vibrate(55);
                    } else {
                        lives--; combo=1; shake=24; flash=.26f;
                        burst(px,py,28,0xffff315e); vibrate(100);
                        if(lives<=0) over=true;
                    }
                    objects.remove(i);
                }
            }

            for(int i=particles.size()-1;i>=0;i--){
                Particle q=particles.get(i);
                q.life-=dt; q.x+=q.vx*dt; q.y+=q.vy*dt; q.vy+=500*dt;
                if(q.life<=0) particles.remove(i);
            }

            shake=Math.max(0,shake-34*dt);
            flash=Math.max(0,flash-dt);
        }

        private void spawnObject(){
            int n=r.nextInt(100);
            int type = n<45?0 : n<82?1 : n<94?2 : 3;
            float y;
            if(type==1) y=ground-(r.nextBoolean()?38:150);
            else y=ground-(75+r.nextInt((int)Math.max(80,h*.28f)));
            float rad= type==1?34 : type==3?31 : 27;
            objects.add(new Obj(w+80,y,rad,type));

            if(score>1800 && r.nextInt(4)==0)
                objects.add(new Obj(w+250,ground-44,34,1));
            if(score>4200 && r.nextInt(5)==0)
                objects.add(new Obj(w+390,ground-175,34,1));
        }

        private void burst(float x,float y,int count,int color){
            for(int i=0;i<count;i++){
                double a=r.nextDouble()*Math.PI*2;
                float s=100+r.nextFloat()*430;
                Particle q=new Particle(x,y,(float)Math.cos(a)*s,(float)Math.sin(a)*s,
                        .35f+r.nextFloat()*.65f,3+r.nextFloat()*8);
                q.size = q.size + (color & 1);
                particles.add(q);
            }
        }

        private void vibrate(long ms){
            try{
                Vibrator v=(Vibrator)getContext().getSystemService(Context.VIBRATOR_SERVICE);
                if(v==null)return;
                if(Build.VERSION.SDK_INT>=26) v.vibrate(VibrationEffect.createOneShot(ms,160));
                else v.vibrate(ms);
            }catch(Exception ignored){}
        }

        private void drawWorld(Canvas c){
            c.save();
            if(shake>0) c.translate((r.nextFloat()-.5f)*shake,(r.nextFloat()-.5f)*shake);

            LinearGradient bg=new LinearGradient(0,0,0,h,
                    new int[]{0xff05010a,0xff210028,0xff05020b},null,Shader.TileMode.CLAMP);
            p.setShader(bg); c.drawRect(0,0,w,h,p); p.setShader(null);

            // moving neon skyline
            for(int i=0;i<12;i++){
                float bx=((i*143)-(score*.12f))%(w+180);
                if(bx<0) bx+=w+180;
                float bh=100+(i%5)*45;
                p.setColor(i%2==0?0x332eeaff:0x33ff42bd);
                c.drawRect(bx,h*.63f-bh,bx+70,h*.63f,p);
                p.setColor(0x55ffffff);
                for(int j=0;j<3;j++) c.drawRect(bx+12+j*18,h*.63f-bh+18,bx+20+j*18,h*.63f-bh+28,p);
            }

            p.setColor(0xff11051a); c.drawRect(0,ground,w,h,p);
            p.setColor(0xffff48bf); c.drawRect(0,ground,w,ground+7,p);

            p.setStrokeWidth(2);
            p.setColor(0x444de8ff);
            for(int i=1;i<8;i++) c.drawLine(0,ground+i*34,w,ground+i*34,p);
            for(int i=-8;i<=8;i++) c.drawLine(w/2,ground,w/2+i*105,h,p);

            for(Obj o:objects) drawObject(c,o);
            drawPanther(c,px,py);

            for(Particle q:particles){
                p.setColor(0xffff59c7);
                p.setAlpha((int)(255*Math.max(0,Math.min(1,q.life))));
                c.drawCircle(q.x,q.y,q.size,p);
                p.setAlpha(255);
            }

            drawHud(c);
            if(!started && !over) drawStart(c);
            if(over) drawOver(c);

            if(flash>0){
                p.setColor(0x55ffffff); c.drawRect(0,0,w,h,p);
            }
            c.restore();
        }

        private void drawObject(Canvas c,Obj o){
            if(o.type==0){
                p.setStyle(Paint.Style.STROKE); p.setStrokeWidth(8); p.setColor(0xffffd54a);
                c.drawCircle(o.x,o.y,o.rad,p);
                p.setStyle(Paint.Style.FILL); p.setColor(0xffff9e2c); c.drawCircle(o.x,o.y,8,p);
            } else if(o.type==1){
                p.setColor(0xffff315e);
                c.drawRoundRect(o.x-o.rad,o.y-o.rad,o.x+o.rad,o.y+o.rad,12,12,p);
                p.setStrokeWidth(6); p.setColor(Color.WHITE);
                c.drawLine(o.x-18,o.y-18,o.x+18,o.y+18,p);
                c.drawLine(o.x+18,o.y-18,o.x-18,o.y+18,p);
            } else if(o.type==2){
                p.setColor(0xff4de8ff); c.drawCircle(o.x,o.y,o.rad,p);
                p.setTextAlign(Paint.Align.CENTER); p.setTextSize(27); p.setColor(0xff06101a);
                c.drawText("S",o.x,o.y+10,p);
            } else {
                p.setColor(0xffb65cff); c.drawCircle(o.x,o.y,o.rad,p);
                p.setTextAlign(Paint.Align.CENTER); p.setTextSize(24); p.setColor(Color.WHITE);
                c.drawText("MAX",o.x,o.y+8,p);
            }
        }

        private void drawPanther(Canvas c,float x,float y){
            p.setColor(0xffff62c8);
            c.drawOval(x-43,y-24,x+43,y+31,p);
            c.drawCircle(x+35,y-43,29,p);

            Path e1=new Path(); e1.moveTo(x+17,y-62); e1.lineTo(x+29,y-93); e1.lineTo(x+42,y-62); e1.close(); c.drawPath(e1,p);
            Path e2=new Path(); e2.moveTo(x+40,y-63); e2.lineTo(x+58,y-89); e2.lineTo(x+63,y-53); e2.close(); c.drawPath(e2,p);

            p.setStyle(Paint.Style.STROKE); p.setStrokeWidth(13);
            Path tail=new Path(); tail.moveTo(x-37,y-14); tail.cubicTo(x-112,y-76,x-132,y+42,x-72,y+58); c.drawPath(tail,p);
            p.setStyle(Paint.Style.FILL);

            c.drawRoundRect(x-28,y+18,x-8,y+72,8,8,p);
            c.drawRoundRect(x+18,y+16,x+37,y+72,8,8,p);

            p.setColor(0xff130417); c.drawCircle(x+44,y-47,5,p);
            p.setColor(Color.WHITE); c.drawCircle(x+42,y-49,2,p);
            p.setColor(0xffffd54a); c.drawCircle(x-5,y-9,7,p);
        }

        private void drawHud(Canvas c){
            p.setTextAlign(Paint.Align.LEFT); p.setColor(Color.WHITE); p.setTextSize(31);
            c.drawText("SCORE  "+score,24,48,p);
            p.setTextSize(19); p.setColor(0xffff62c8);
            c.drawText("RINGS "+coins+"   COMBO x"+combo,25,78,p);

            p.setTextAlign(Paint.Align.RIGHT); p.setTextSize(28); p.setColor(0xffff4fc3);
            String hp=""; for(int i=0;i<Math.max(0,lives);i++) hp+="♥";
            c.drawText(hp,w-25,50,p);

            if(slow>0){
                p.setTextAlign(Paint.Align.CENTER); p.setTextSize(20); p.setColor(0xff4de8ff);
                c.drawText("CHRONO MODE  "+String.format(Locale.US,"%.1f",slow),w/2,108,p);
            }
        }

        private void drawStart(Canvas c){
            p.setTextAlign(Paint.Align.CENTER);
            p.setColor(0xffff62c8); p.setTextSize(48); c.drawText("NEON PANTHER",w/2,h*.31f,p);
            p.setColor(Color.WHITE); p.setTextSize(22); c.drawText("HEIST // CHAOS RUN",w/2,h*.31f+38,p);
            p.setColor(0xffdddddd); p.setTextSize(18);
            c.drawText("Tap = jump   •   Swipe = dash",w/2,h*.58f,p);
            c.drawText("Gold = rings   Cyan S = slow-mo   Purple MAX = x9",w/2,h*.58f+30,p);
            p.setColor(0xffffd54a); p.setTextSize(27); c.drawText("TAP TO START",w/2,h*.70f,p);
        }

        private void drawOver(Canvas c){
            p.setColor(0xcc050108); c.drawRect(0,0,w,h,p);
            p.setTextAlign(Paint.Align.CENTER); p.setColor(0xffff315e); p.setTextSize(55);
            c.drawText("BUSTED!",w/2,h*.38f,p);
            p.setColor(Color.WHITE); p.setTextSize(25);
            c.drawText("Score "+score+"   •   Rings "+coins,w/2,h*.46f,p);
            p.setColor(0xffff62c8); p.setTextSize(25);
            c.drawText("Tap to unleash chaos again",w/2,h*.58f,p);
        }

        @Override public boolean onTouchEvent(MotionEvent e){
            if(e.getAction()==MotionEvent.ACTION_DOWN){
                downX=e.getX(); downY=e.getY(); return true;
            }
            if(e.getAction()==MotionEvent.ACTION_UP){
                float dx=e.getX()-downX, dy=e.getY()-downY;
                if(over){ reset(); started=true; return true; }
                if(!started){ started=true; return true; }

                if(Math.abs(dx)>75 && Math.abs(dx)>Math.abs(dy)){
                    vx=(dx>0?1:-1)*820f;
                    postDelayed(() -> vx=0,170);
                    burst(px,py,9,0xffff62c8);
                } else if(py>=ground-68){
                    vy=-900f; burst(px,py+48,9,0xff4de8ff); vibrate(22);
                }
                return true;
            }
            return true;
        }
    }
}
