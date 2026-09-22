package com.raul.neonpanther3d;

import android.app.Activity;
import android.os.Bundle;
import android.os.Build;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Typeface;
import android.opengl.GLES20;
import android.opengl.GLSurfaceView;
import android.opengl.Matrix;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import android.widget.FrameLayout;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.Locale;
import java.util.Random;

public class MainActivity extends Activity {
    GameView game;
    HudView hud;

    @Override public void onCreate(Bundle b) {
        super.onCreate(b);
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN, WindowManager.LayoutParams.FLAG_FULLSCREEN);
        getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_FULLSCREEN |
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION |
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY |
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN |
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION |
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE);

        FrameLayout root = new FrameLayout(this);
        game = new GameView(this);
        hud = new HudView(this, game.renderer);
        root.addView(game, new FrameLayout.LayoutParams(-1,-1));
        root.addView(hud, new FrameLayout.LayoutParams(-1,-1));
        setContentView(root);
    }

    @Override protected void onPause(){ super.onPause(); if(game!=null) game.onPause(); }
    @Override protected void onResume(){ super.onResume(); if(game!=null) game.onResume(); }

    static class HudView extends View {
        final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        final Renderer3D r;
        HudView(Context c, Renderer3D r){
            super(c); this.r=r; setWillNotDraw(false);
            p.setTypeface(Typeface.create("sans-serif-black", Typeface.BOLD));
        }
        @Override protected void onDraw(Canvas c){
            super.onDraw(c);
            float w=getWidth(), h=getHeight();

            p.setTextAlign(Paint.Align.LEFT);
            p.setColor(Color.WHITE); p.setTextSize(34);
            c.drawText("SCORE  "+r.score, 24, 50, p);
            p.setTextSize(21); p.setColor(0xffff68c8);
            c.drawText("COINS  "+r.coins+"    SPEED  "+String.format(Locale.US,"%.1f",r.speed),24,82,p);

            if(!r.started && !r.gameOver){
                p.setTextAlign(Paint.Align.CENTER);
                p.setColor(0xffff5fc8); p.setTextSize(50);
                c.drawText("NEON PANTHER",w/2,h*.25f,p);
                p.setColor(Color.WHITE); p.setTextSize(26);
                c.drawText("RUSH 3D",w/2,h*.25f+40,p);
                p.setTextSize(19); p.setColor(0xffeeeeee);
                c.drawText("Swipe left/right = change lane",w/2,h*.63f,p);
                c.drawText("Swipe up = jump   •   Swipe down = slide",w/2,h*.63f+32,p);
                p.setColor(0xffffd85e); p.setTextSize(30);
                c.drawText("TAP TO RUN",w/2,h*.76f,p);
            }

            if(r.gameOver){
                p.setColor(0xaa05000a); c.drawRect(0,0,w,h,p);
                p.setTextAlign(Paint.Align.CENTER);
                p.setColor(0xffff416c); p.setTextSize(58);
                c.drawText("CAUGHT!",w/2,h*.39f,p);
                p.setColor(Color.WHITE); p.setTextSize(26);
                c.drawText("Score "+r.score+"   •   Coins "+r.coins,w/2,h*.47f,p);
                p.setColor(0xffff6cca); p.setTextSize(25);
                c.drawText("Tap to run again",w/2,h*.58f,p);
            }

            if(r.flash>0){
                p.setColor(0x44ffffff); c.drawRect(0,0,w,h,p);
            }
            postInvalidateOnAnimation();
        }
    }

    static class GameView extends GLSurfaceView {
        final Renderer3D renderer;
        float downX, downY;
        GameView(Context c){
            super(c);
            setEGLContextClientVersion(2);
            renderer=new Renderer3D(c);
            setRenderer(renderer);
            setRenderMode(GLSurfaceView.RENDERMODE_CONTINUOUSLY);
        }
        @Override public boolean onTouchEvent(MotionEvent e){
            if(e.getAction()==MotionEvent.ACTION_DOWN){
                downX=e.getX(); downY=e.getY(); return true;
            }
            if(e.getAction()==MotionEvent.ACTION_UP){
                float dx=e.getX()-downX, dy=e.getY()-downY;
                final int cmd;
                if(Math.abs(dx)<55 && Math.abs(dy)<55) cmd=0;
                else if(Math.abs(dx)>Math.abs(dy)) cmd=dx<0?1:2;
                else cmd=dy<0?3:4;
                queueEvent(() -> renderer.command(cmd));
                return true;
            }
            return true;
        }
    }

    static class Renderer3D implements GLSurfaceView.Renderer {
        final Context ctx;
        final Random rand = new Random(7);

        volatile boolean started=false, gameOver=false;
        volatile int score=0, coins=0;
        volatile float speed=8.5f, flash=0;

        int program, aPos, aNormal, uMVP, uModel, uColor, uLight;
        Mesh cube, sphere, cylinder, coinMesh;

        final float[] proj=new float[16], view=new float[16], vp=new float[16];
        final float[] model=new float[16], mvp=new float[16];

        float playerX=0, targetX=0;
        int lane=1;
        float jumpY=0, jumpV=0, slide=0, runT=0, distance=0;
        float obstacleTimer=.7f, coinTimer=.15f;
        long last=System.nanoTime();

        final ArrayList<Obstacle> obstacles=new ArrayList<>();
        final ArrayList<Coin> coinList=new ArrayList<>();

        static final float[] PINK={1f,.30f,.66f,1f};
        static final float[] PINK2={.94f,.18f,.54f,1f};
        static final float[] CREAM={1f,.87f,.68f,1f};
        static final float[] BLACK={.035f,.02f,.045f,1f};
        static final float[] BLUE={.12f,.22f,.40f,1f};
        static final float[] GOLD={1f,.72f,.12f,1f};
        static final float[] ROAD={.075f,.08f,.10f,1f};
        static final float[] SIDE={.26f,.25f,.31f,1f};
        static final float[] WHITE={.92f,.92f,.95f,1f};
        static final float[] RED={.95f,.12f,.18f,1f};
        static final float[] CYAN={.16f,.88f,1f,1f};
        static final float[] DARKWIN={.08f,.11f,.18f,1f};

        static class Obstacle {
            int lane,type; float z;
            Obstacle(int l,int t,float z){lane=l;type=t;this.z=z;}
        }
        static class Coin {
            int lane; float z,y,spin;
            Coin(int l,float z,float y){lane=l;this.z=z;this.y=y;}
        }

        Renderer3D(Context c){ctx=c;}

        @Override public void onSurfaceCreated(javax.microedition.khronos.opengles.GL10 gl,
                                               javax.microedition.khronos.egl.EGLConfig config){
            GLES20.glClearColor(.035f,.015f,.07f,1f);
            GLES20.glEnable(GLES20.GL_DEPTH_TEST);
            GLES20.glDepthFunc(GLES20.GL_LEQUAL);

            String vs=
                    "uniform mat4 uMVP;\n"+
                    "uniform mat4 uModel;\n"+
                    "attribute vec3 aPos;\n"+
                    "attribute vec3 aNormal;\n"+
                    "varying vec3 vN;\n"+
                    "varying vec3 vWorld;\n"+
                    "void main(){ vec4 wp=uModel*vec4(aPos,1.0); vWorld=wp.xyz; vN=normalize(mat3(uModel)*aNormal); gl_Position=uMVP*vec4(aPos,1.0); }";
            String fs=
                    "precision mediump float;\n"+
                    "uniform vec4 uColor;\n"+
                    "uniform vec3 uLight;\n"+
                    "varying vec3 vN;\n"+
                    "varying vec3 vWorld;\n"+
                    "void main(){ float d=max(dot(normalize(vN),normalize(uLight)),0.0); float light=.38+.62*d; float fog=clamp((-vWorld.z-18.0)/105.0,0.0,.58); vec3 col=uColor.rgb*light; col=mix(col,vec3(.11,.025,.16),fog); gl_FragColor=vec4(col,uColor.a); }";

            program=link(vs,fs);
            aPos=GLES20.glGetAttribLocation(program,"aPos");
            aNormal=GLES20.glGetAttribLocation(program,"aNormal");
            uMVP=GLES20.glGetUniformLocation(program,"uMVP");
            uModel=GLES20.glGetUniformLocation(program,"uModel");
            uColor=GLES20.glGetUniformLocation(program,"uColor");
            uLight=GLES20.glGetUniformLocation(program,"uLight");

            cube=Mesh.cube();
            sphere=Mesh.sphere(12,8);
            cylinder=Mesh.cylinder(14);
            coinMesh=Mesh.cylinder(16);
            reset();
        }

        @Override public void onSurfaceChanged(javax.microedition.khronos.opengles.GL10 gl,int w,int h){
            GLES20.glViewport(0,0,w,h);
            Matrix.perspectiveM(proj,0,58f,(float)w/h,.1f,180f);
        }

        @Override public void onDrawFrame(javax.microedition.khronos.opengles.GL10 gl){
            long now=System.nanoTime();
            float dt=Math.min(.033f,(now-last)/1_000_000_000f);
            last=now;
            if(started&&!gameOver) update(dt);

            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT|GLES20.GL_DEPTH_BUFFER_BIT);
            float camY=3.6f + jumpY*.12f;
            Matrix.setLookAtM(view,0,0,camY,8.6f, 0,1.55f,-8.5f, 0,1,0);
            Matrix.multiplyMM(vp,0,proj,0,view,0);

            GLES20.glUseProgram(program);
            GLES20.glUniform3f(uLight,-.35f,.90f,.55f);

            drawWorld();
            drawObjects();
            drawPlayer();
        }

        void reset(){
            started=false; gameOver=false;
            score=0; coins=0; speed=8.5f; flash=0;
            playerX=0; targetX=0; lane=1;
            jumpY=jumpV=slide=runT=distance=0;
            obstacleTimer=.75f; coinTimer=.12f;
            obstacles.clear(); coinList.clear();
            last=System.nanoTime();
        }

        void command(int cmd){
            if(gameOver){ reset(); started=true; return; }
            if(!started){ started=true; return; }
            if(cmd==1 && lane>0){ lane--; targetX=laneX(lane); }
            else if(cmd==2 && lane<2){ lane++; targetX=laneX(lane); }
            else if(cmd==3 && jumpY<=.02f && slide<=0){ jumpV=7.4f; vibrate(20); }
            else if(cmd==4 && jumpY<=.05f){ slide=.75f; vibrate(18); }
            else if(cmd==0 && jumpY<=.02f && slide<=0){ jumpV=7.4f; }
        }

        void update(float dt){
            runT+=dt;
            speed=Math.min(20f,8.5f+distance*.0046f);
            distance+=speed*dt;
            score=(int)(distance*11)+coins*55;

            playerX += (targetX-playerX)*Math.min(1f,dt*12f);
            if(jumpY>0 || jumpV>0){
                jumpV-=18.5f*dt;
                jumpY+=jumpV*dt;
                if(jumpY<0){jumpY=0;jumpV=0;}
            }
            if(slide>0) slide-=dt;
            if(flash>0) flash-=dt;

            obstacleTimer-=dt;
            if(obstacleTimer<=0){
                obstacleTimer=Math.max(.58f,1.30f-(speed-8.5f)*.045f);
                int l=rand.nextInt(3);
                int t=rand.nextInt(100)<48?0:(rand.nextInt(100)<55?1:2);
                obstacles.add(new Obstacle(l,t,-68f));
                if(rand.nextFloat()<.24f){
                    int other=(l+1+rand.nextInt(2))%3;
                    obstacles.add(new Obstacle(other,rand.nextBoolean()?0:2,-72f));
                }
            }

            coinTimer-=dt;
            if(coinTimer<=0){
                coinTimer=.52f;
                int l=rand.nextInt(3);
                int count=4+rand.nextInt(4);
                boolean arc=rand.nextFloat()<.28f;
                for(int i=0;i<count;i++){
                    float y=arc ? .75f+(float)Math.sin(i/(float)(count-1)*Math.PI)*1.55f : .72f;
                    coinList.add(new Coin(l,-40f-i*2.35f,y));
                }
            }

            Iterator<Obstacle> oi=obstacles.iterator();
            while(oi.hasNext()){
                Obstacle o=oi.next();
                o.z+=speed*dt;
                if(o.z>9){oi.remove();continue;}
                if(Math.abs(o.z)<.72f && Math.abs(playerX-laneX(o.lane))<.72f){
                    boolean safe=(o.type==0 && jumpY>.72f) || (o.type==1 && slide>0);
                    if(!safe){
                        gameOver=true; flash=.35f; vibrate(150);
                    }
                }
            }

            Iterator<Coin> ci=coinList.iterator();
            while(ci.hasNext()){
                Coin q=ci.next();
                q.z+=speed*dt; q.spin+=dt*240f;
                if(q.z>8){ci.remove();continue;}
                if(Math.abs(q.z)<.78f && Math.abs(playerX-laneX(q.lane))<.65f &&
                        Math.abs((jumpY+.85f)-q.y)<1.15f){
                    coins++; flash=.07f; ci.remove(); vibrate(10);
                }
            }
        }

        void drawWorld(){
            float scroll=distance%12f;
            int base=(int)(distance/12f);

            // Road, sidewalks, lane markings and city blocks.
            for(int i=0;i<16;i++){
                float z=-i*12f+scroll+4f;
                draw(cube,0,-.18f,z, 7.8f,.22f,6f,0,0,0,ROAD);
                draw(cube,-5.05f,-.02f,z, 1.15f,.25f,6f,0,0,0,SIDE);
                draw(cube, 5.05f,-.02f,z, 1.15f,.25f,6f,0,0,0,SIDE);

                if(i%1==0){
                    draw(cube,-1.20f,.025f,z, .055f,.018f,1.45f,0,0,0,WHITE);
                    draw(cube, 1.20f,.025f,z, .055f,.018f,1.45f,0,0,0,WHITE);
                }

                int idx=base+i;
                for(int side=-1;side<=1;side+=2){
                    float h1=3.5f+hash(idx*13+side*7)*6.5f;
                    float w1=1.7f+hash(idx*17+2)*1.5f;
                    float x=side*(7.2f+hash(idx*9+side)*2.0f);
                    float col=hash(idx*11+side*3);
                    float[] bc= col<.33f?new float[]{.23f,.12f,.35f,1}:col<.66f?new float[]{.09f,.22f,.34f,1}:new float[]{.31f,.10f,.22f,1};
                    draw(cube,x,h1*.5f-.05f,z-.8f,w1,h1*.5f,2.8f,0,0,0,bc);

                    // glowing window strips
                    for(int floor=0;floor<4;floor++){
                        float wy=.8f+floor*(h1/4.8f);
                        float faceX=x-side*(w1+.015f);
                        draw(cube,faceX,wy,z+.5f,.025f,.11f,.55f,0,0,0,(floor+idx)%3==0?GOLD:CYAN);
                    }

                    if(idx%3==0){
                        draw(cylinder,side*5.75f,1.35f,z-2.7f,.055f,1.35f,.055f,0,0,0,BLACK);
                        draw(sphere,side*5.75f,2.72f,z-2.7f,.18f,.18f,.18f,0,0,0,GOLD);
                    }
                }
            }

            // distant skyline towers
            for(int i=0;i<9;i++){
                float x=(i-4)*4.6f;
                float hh=7f+(i%4)*2.2f;
                draw(cube,x,hh*.5f-1f,-115f-i*3f,1.65f,hh*.5f,2.2f,0,0,0,
                        i%2==0?new float[]{.18f,.07f,.30f,1}:new float[]{.05f,.18f,.28f,1});
            }
        }

        void drawObjects(){
            for(Coin q:coinList){
                float x=laneX(q.lane);
                draw(coinMesh,x,q.y,q.z,.30f,.065f,.30f,90,q.spin,0,GOLD);
                draw(sphere,x,q.y,q.z,.11f,.11f,.11f,0,0,0,new float[]{1f,.93f,.45f,1});
            }

            for(Obstacle o:obstacles){
                float x=laneX(o.lane);
                if(o.type==0){
                    // jump barrier
                    draw(cube,x,.42f,o.z,1.00f,.42f,.28f,0,0,0,RED);
                    draw(cube,x,.44f,o.z-.30f,.86f,.07f,.03f,0,0,0,WHITE);
                    draw(cube,x,.44f,o.z+.30f,.86f,.07f,.03f,0,0,0,WHITE);
                }else if(o.type==1){
                    // overhead sign: slide underneath
                    draw(cylinder,x-1.0f,1.15f,o.z,.07f,1.15f,.07f,0,0,0,BLACK);
                    draw(cylinder,x+1.0f,1.15f,o.z,.07f,1.15f,.07f,0,0,0,BLACK);
                    draw(cube,x,2.05f,o.z,1.1f,.30f,.16f,0,0,0,new float[]{.72f,.10f,.80f,1});
                    draw(cube,x,2.05f,o.z-.17f,.75f,.08f,.02f,0,0,0,WHITE);
                }else{
                    // stylized moving road vehicle
                    draw(cube,x,.46f,o.z,1.0f,.42f,1.55f,0,0,0,new float[]{.08f,.58f,.90f,1});
                    draw(cube,x,.90f,o.z-.15f,.72f,.34f,.72f,0,0,0,DARKWIN);
                    draw(cylinder,x-.70f,.20f,o.z-.82f,.18f,.14f,.18f,90,0,0,BLACK);
                    draw(cylinder,x+.70f,.20f,o.z-.82f,.18f,.14f,.18f,90,0,0,BLACK);
                    draw(cylinder,x-.70f,.20f,o.z+.82f,.18f,.14f,.18f,90,0,0,BLACK);
                    draw(cylinder,x+.70f,.20f,o.z+.82f,.18f,.14f,.18f,90,0,0,BLACK);
                }
            }
        }

        void drawPlayer(){
            float bob=(float)Math.sin(runT*11f)*.045f;
            float base=.18f+jumpY+bob;
            float squash=slide>0 ? .55f : 1f;
            float arm=(float)Math.sin(runT*11f)*35f;
            float leg=(float)Math.sin(runT*11f+Math.PI)*34f;

            // shadow
            draw(sphere,playerX,.035f,.18f, .62f,.035f,.34f,0,0,0,new float[]{.02f,.01f,.025f,.55f});

            // long legs
            float legY=base+.58f*squash;
            draw(cylinder,playerX-.23f,legY,-.02f,.105f,.48f*squash,.105f,leg,0,0,PINK);
            draw(cylinder,playerX+.23f,legY,-.02f,.105f,.48f*squash,.105f,-leg,0,0,PINK);

            // big feline feet
            draw(sphere,playerX-.25f,base+.10f,-.20f,.30f,.13f,.48f,0,0,0,PINK);
            draw(sphere,playerX+.25f,base+.10f,-.20f,.30f,.13f,.48f,0,0,0,PINK);

            // shorts
            draw(cube,playerX,base+1.03f*squash,-.02f,.43f,.30f*squash,.27f,0,0,0,BLUE);

            // pink oversized shirt torso
            draw(cube,playerX,base+1.52f*squash,-.02f,.52f,.50f*squash,.30f,0,0,0,PINK2);

            // sleeves + swinging arms
            draw(cylinder,playerX-.56f,base+1.55f*squash,-.01f,.12f,.43f*squash,.12f,arm,0,18,PINK);
            draw(cylinder,playerX+.56f,base+1.55f*squash,-.01f,.12f,.43f*squash,.12f,-arm,0,-18,PINK);
            draw(sphere,playerX-.66f,base+1.15f*squash,.02f,.15f,.15f,.15f,0,0,0,PINK);
            draw(sphere,playerX+.66f,base+1.15f*squash,.02f,.15f,.15f,.15f,0,0,0,PINK);

            // neck
            draw(cylinder,playerX,base+2.03f*squash,-.02f,.13f,.25f*squash,.13f,0,0,0,PINK);

            // gold chain beads
            for(int i=-3;i<=3;i++){
                float xx=playerX+i*.105f;
                float yy=base+1.92f*squash-(float)Math.abs(i)*.018f;
                draw(sphere,xx,yy,.28f,.055f,.055f,.055f,0,0,0,GOLD);
            }
            draw(cube,playerX,base+1.78f*squash,.30f,.08f,.11f,.035f,0,0,0,GOLD);

            // head
            draw(sphere,playerX,base+2.42f*squash,-.05f,.48f,.52f*squash,.44f,0,0,0,PINK);
            // ears
            draw(sphere,playerX-.34f,base+2.75f*squash,-.06f,.16f,.22f*squash,.12f,0,0,-18,PINK);
            draw(sphere,playerX+.34f,base+2.75f*squash,-.06f,.16f,.22f*squash,.12f,0,0,18,PINK);

            // muzzle / nose on the forward face (-Z)
            draw(sphere,playerX-.17f,base+2.28f*squash,-.42f,.22f,.18f*squash,.15f,0,0,0,CREAM);
            draw(sphere,playerX+.17f,base+2.28f*squash,-.42f,.22f,.18f*squash,.15f,0,0,0,CREAM);
            draw(sphere,playerX,base+2.39f*squash,-.52f,.12f,.095f*squash,.08f,0,0,0,PINK2);

            // black sunglasses with silver glint
            draw(cube,playerX-.22f,base+2.54f*squash,-.45f,.21f,.13f*squash,.035f,-8,0,0,BLACK);
            draw(cube,playerX+.22f,base+2.54f*squash,-.45f,.21f,.13f*squash,.035f,-8,0,0,BLACK);
            draw(cube,playerX,base+2.55f*squash,-.46f,.07f,.035f,.025f,0,0,0,BLACK);
            draw(cube,playerX-.26f,base+2.59f*squash,-.49f,.07f,.012f,.008f,-8,0,0,WHITE);
            draw(cube,playerX+.18f,base+2.59f*squash,-.49f,.07f,.012f,.008f,-8,0,0,WHITE);

            // backwards cap
            draw(cylinder,playerX,base+2.88f*squash,-.01f,.31f,.06f,.31f,0,0,0,BLACK);
            draw(cube,playerX,base+2.91f*squash,.26f,.28f,.045f,.18f,0,0,0,PINK2);

            // recognizable long curling tail, visible from chase camera
            for(int i=0;i<11;i++){
                float t=i/10f;
                float tx=playerX+.32f+(float)Math.sin(t*4.4f)*.35f;
                float ty=base+.92f+t*.18f+(float)Math.sin(t*3.2f)*.18f;
                float tz=.22f+t*1.28f;
                draw(sphere,tx,ty,tz,.105f,.105f,.105f,0,0,0,PINK);
            }
        }

        float laneX(int l){return (l-1)*2.40f;}
        float hash(int n){
            double v=Math.sin(n*12.9898+78.233)*43758.5453;
            return (float)(v-Math.floor(v));
        }

        void draw(Mesh mesh,float x,float y,float z,float sx,float sy,float sz,
                  float rx,float ry,float rz,float[] color){
            Matrix.setIdentityM(model,0);
            Matrix.translateM(model,0,x,y,z);
            Matrix.rotateM(model,0,rx,1,0,0);
            Matrix.rotateM(model,0,ry,0,1,0);
            Matrix.rotateM(model,0,rz,0,0,1);
            Matrix.scaleM(model,0,sx,sy,sz);
            Matrix.multiplyMM(mvp,0,vp,0,model,0);

            GLES20.glUniformMatrix4fv(uModel,1,false,model,0);
            GLES20.glUniformMatrix4fv(uMVP,1,false,mvp,0);
            GLES20.glUniform4f(uColor,color[0],color[1],color[2],color[3]);

            mesh.pos.position(0); mesh.norm.position(0);
            GLES20.glEnableVertexAttribArray(aPos);
            GLES20.glEnableVertexAttribArray(aNormal);
            GLES20.glVertexAttribPointer(aPos,3,GLES20.GL_FLOAT,false,0,mesh.pos);
            GLES20.glVertexAttribPointer(aNormal,3,GLES20.GL_FLOAT,false,0,mesh.norm);
            GLES20.glDrawArrays(GLES20.GL_TRIANGLES,0,mesh.count);
        }

        int compile(int type,String s){
            int sh=GLES20.glCreateShader(type);
            GLES20.glShaderSource(sh,s); GLES20.glCompileShader(sh);
            int[] ok=new int[1]; GLES20.glGetShaderiv(sh,GLES20.GL_COMPILE_STATUS,ok,0);
            if(ok[0]==0) throw new RuntimeException(GLES20.glGetShaderInfoLog(sh));
            return sh;
        }
        int link(String vs,String fs){
            int p=GLES20.glCreateProgram();
            GLES20.glAttachShader(p,compile(GLES20.GL_VERTEX_SHADER,vs));
            GLES20.glAttachShader(p,compile(GLES20.GL_FRAGMENT_SHADER,fs));
            GLES20.glLinkProgram(p);
            int[] ok=new int[1]; GLES20.glGetProgramiv(p,GLES20.GL_LINK_STATUS,ok,0);
            if(ok[0]==0) throw new RuntimeException(GLES20.glGetProgramInfoLog(p));
            return p;
        }

        void vibrate(long ms){
            try{
                Vibrator v=(Vibrator)ctx.getSystemService(Context.VIBRATOR_SERVICE);
                if(v==null)return;
                if(Build.VERSION.SDK_INT>=26) v.vibrate(VibrationEffect.createOneShot(ms,120));
                else v.vibrate(ms);
            }catch(Exception ignored){}
        }
    }

    static class Mesh {
        final FloatBuffer pos,norm;
        final int count;
        Mesh(float[] p,float[] n){
            count=p.length/3;
            pos=buf(p); norm=buf(n);
        }
        static FloatBuffer buf(float[] a){
            FloatBuffer b=ByteBuffer.allocateDirect(a.length*4).order(ByteOrder.nativeOrder()).asFloatBuffer();
            b.put(a).position(0); return b;
        }

        static Mesh cube(){
            float[] p={
                // front
                -1,-1,1, 1,-1,1, 1,1,1, -1,-1,1, 1,1,1, -1,1,1,
                // back
                1,-1,-1, -1,-1,-1, -1,1,-1, 1,-1,-1, -1,1,-1, 1,1,-1,
                // left
                -1,-1,-1, -1,-1,1, -1,1,1, -1,-1,-1, -1,1,1, -1,1,-1,
                // right
                1,-1,1, 1,-1,-1, 1,1,-1, 1,-1,1, 1,1,-1, 1,1,1,
                // top
                -1,1,1, 1,1,1, 1,1,-1, -1,1,1, 1,1,-1, -1,1,-1,
                // bottom
                -1,-1,-1, 1,-1,-1, 1,-1,1, -1,-1,-1, 1,-1,1, -1,-1,1
            };
            float[] n=new float[p.length];
            int k=0;
            float[][] ns={{0,0,1},{0,0,-1},{-1,0,0},{1,0,0},{0,1,0},{0,-1,0}};
            for(float[] nn:ns) for(int i=0;i<6;i++){n[k++]=nn[0];n[k++]=nn[1];n[k++]=nn[2];}
            return new Mesh(p,n);
        }

        static Mesh sphere(int slices,int stacks){
            ArrayList<Float> pv=new ArrayList<>(), nv=new ArrayList<>();
            for(int j=0;j<stacks;j++){
                float v0=(float)j/stacks, v1=(float)(j+1)/stacks;
                float a0=(v0-.5f)*(float)Math.PI, a1=(v1-.5f)*(float)Math.PI;
                for(int i=0;i<slices;i++){
                    float u0=(float)i/slices, u1=(float)(i+1)/slices;
                    float b0=u0*(float)Math.PI*2, b1=u1*(float)Math.PI*2;
                    addSphereTri(pv,nv,a0,b0,a1,b0,a1,b1);
                    addSphereTri(pv,nv,a0,b0,a1,b1,a0,b1);
                }
            }
            return new Mesh(toArray(pv),toArray(nv));
        }
        static void addSphereTri(ArrayList<Float> p,ArrayList<Float> n,float... ab){
            for(int i=0;i<ab.length;i+=2){
                float a=ab[i], b=ab[i+1];
                float x=(float)(Math.cos(a)*Math.cos(b));
                float y=(float)Math.sin(a);
                float z=(float)(Math.cos(a)*Math.sin(b));
                p.add(x);p.add(y);p.add(z); n.add(x);n.add(y);n.add(z);
            }
        }

        static Mesh cylinder(int sides){
            ArrayList<Float> p=new ArrayList<>(), n=new ArrayList<>();
            for(int i=0;i<sides;i++){
                float a0=(float)(i*Math.PI*2/sides), a1=(float)((i+1)*Math.PI*2/sides);
                float x0=(float)Math.cos(a0), z0=(float)Math.sin(a0);
                float x1=(float)Math.cos(a1), z1=(float)Math.sin(a1);
                addTri(p,n,x0,-1,z0,x1,-1,z1,x1,1,z1,x0,0,z0,x1,0,z1,x1,0,z1);
                addTri(p,n,x0,-1,z0,x1,1,z1,x0,1,z0,x0,0,z0,x1,0,z1,x0,0,z0);
                // top
                addTri(p,n,0,1,0,x0,1,z0,x1,1,z1,0,1,0,0,1,0,0,1,0);
                // bottom
                addTri(p,n,0,-1,0,x1,-1,z1,x0,-1,z0,0,-1,0,0,-1,0,0,-1,0);
            }
            return new Mesh(toArray(p),toArray(n));
        }

        static void addTri(ArrayList<Float> p,ArrayList<Float> n,
                           float ax,float ay,float az,float bx,float by,float bz,float cx,float cy,float cz,
                           float anx,float any,float anz,float bnx,float bny,float bnz,float cnx,float cny,float cnz){
            p.add(ax);p.add(ay);p.add(az); p.add(bx);p.add(by);p.add(bz); p.add(cx);p.add(cy);p.add(cz);
            n.add(anx);n.add(any);n.add(anz); n.add(bnx);n.add(bny);n.add(bnz); n.add(cnx);n.add(cny);n.add(cnz);
        }
        static float[] toArray(ArrayList<Float> a){
            float[] out=new float[a.size()];
            for(int i=0;i<out.length;i++)out[i]=a.get(i);
            return out;
        }
    }
}
