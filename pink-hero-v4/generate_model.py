import math, os
import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial

BASE=os.path.dirname(__file__)
OUT=os.path.join(BASE,"generated","PinkHeroV4.glb")
os.makedirs(os.path.dirname(OUT),exist_ok=True)
scene=trimesh.Scene()

def rgba(hex_color):
    h=hex_color.lstrip("#")
    return [int(h[i:i+2],16) for i in (0,2,4)] + [255]

def material(name,color,rough=0.7,metal=0.0):
    return PBRMaterial(name=name,baseColorFactor=rgba(color),metallicFactor=metal,roughnessFactor=rough)

FUR=material("Fur_Pink","#f56eaa",0.82,0.0)
CREAM=material("Fur_Cream","#f2ddc7",0.88,0.0)
SHIRT=material("Shirt_Pink","#e879a6",0.76,0.0)
SHIRT_DARK=material("Shirt_Seams","#bb4b78",0.82,0.0)
DENIM=material("Denim","#5a7fa8",0.88,0.0)
DENIM_DARK=material("Denim_Stitch","#355b80",0.86,0.0)
BLACK=material("Black","#111117",0.32,0.05)
GLASS=material("Sunglass_Lens","#172235",0.16,0.20)
GOLD=material("Gold","#d5a21a",0.20,0.95)
NOSE=material("Nose","#c72d63",0.42,0.0)
WHITE=material("Highlight","#f8edf1",0.70,0.0)

def add(mesh,name,mat):
    mesh.visual=trimesh.visual.TextureVisuals(material=mat)
    scene.add_geometry(mesh,node_name=name,geom_name=name)
    return mesh

def ellipsoid(center,scale,mat,name,subdivisions=3,deform=None):
    m=trimesh.creation.icosphere(subdivisions=subdivisions,radius=1.0)
    v=m.vertices.copy()
    if deform:
        v=deform(v)
    v*=np.asarray(scale,float)
    v+=np.asarray(center,float)
    m.vertices=v
    return add(m,name,mat)

def tube(path,radii,mat,name,nrad=20):
    p=np.asarray(path,float)
    if np.isscalar(radii):
        radii=[float(radii)]*len(p)
    r=np.asarray(radii,float)
    verts=[]; faces=[]; prev_u=None
    for i,pt in enumerate(p):
        if i==0: tangent=p[1]-p[0]
        elif i==len(p)-1: tangent=p[-1]-p[-2]
        else: tangent=p[i+1]-p[i-1]
        tangent=tangent/max(np.linalg.norm(tangent),1e-8)
        if prev_u is None:
            ref=np.array([0.,1.,0.])
            if abs(np.dot(ref,tangent))>.85:
                ref=np.array([0.,0.,1.])
            u=np.cross(tangent,ref)
            u=u/max(np.linalg.norm(u),1e-8)
        else:
            u=prev_u-tangent*np.dot(prev_u,tangent)
            if np.linalg.norm(u)<1e-6:
                u=np.cross(tangent,np.array([0.,0.,1.]))
            u=u/max(np.linalg.norm(u),1e-8)
        v=np.cross(tangent,u)
        v=v/max(np.linalg.norm(v),1e-8)
        prev_u=u
        for j in range(nrad):
            a=2*math.pi*j/nrad
            verts.append(pt+r[i]*(math.cos(a)*u+math.sin(a)*v))
    for i in range(len(p)-1):
        for j in range(nrad):
            a=i*nrad+j
            b=i*nrad+(j+1)%nrad
            c=(i+1)*nrad+(j+1)%nrad
            d=(i+1)*nrad+j
            faces.extend([[a,b,c],[a,c,d]])
    return add(trimesh.Trimesh(vertices=np.asarray(verts),faces=np.asarray(faces),process=True),name,mat)

def shell(y0,y1,rx0,rx1,rz0,rz1,mat,name,n_y=18,nrad=32,fold=0.0):
    ys=np.linspace(y0,y1,n_y)
    verts=[]; faces=[]
    for iy,y in enumerate(ys):
        t=iy/(n_y-1)
        s=math.sin(math.pi*t)
        rx=(1-t)*rx0+t*rx1+0.08*s
        rz=(1-t)*rz0+t*rz1+0.03*s
        for j in range(nrad):
            a=2*math.pi*j/nrad
            f=fold*(1-t)*(0.6*math.sin(4*a+iy*.65)+0.4*math.sin(9*a-iy*.35))
            verts.append([(rx+f)*math.cos(a),y,(rz+f)*math.sin(a)])
    for i in range(n_y-1):
        for j in range(nrad):
            a=i*nrad+j
            b=i*nrad+(j+1)%nrad
            c=(i+1)*nrad+(j+1)%nrad
            d=(i+1)*nrad+j
            faces.extend([[a,b,c],[a,c,d]])
    return add(trimesh.Trimesh(vertices=np.asarray(verts),faces=np.asarray(faces),process=True),name,mat)

def torus_at(center,major,minor,mat,name,rot=None,sections=18):
    m=trimesh.creation.torus(major_radius=major,minor_radius=minor,major_sections=sections,minor_sections=10)
    if rot:
        m.apply_transform(trimesh.transformations.euler_matrix(*rot))
    m.apply_translation(center)
    return add(m,name,mat)

# Slim legs + large paws
for label,x in [("L",-0.21),("R",0.21)]:
    tube([[x,1.43,0.00],[x*.98,1.12,.015],[x*.96,.72,-.01],[x,.30,-.035]],[.11,.105,.108,.12],FUR,f"Leg_{label}",22)
    def paw_deform(v):
        vv=v.copy()
        vv[:,2]+=0.13*(vv[:,1]<-0.05)
        vv[:,0]*=(1.0+0.10*np.maximum(0,-vv[:,2]))
        return vv
    ellipsoid([x,.11,.29],[.30,.18,.46],FUR,f"Paw_{label}",3,paw_deform)
    for k,dx in enumerate([-.105,0,.105]):
        ellipsoid([x+dx,.10,.62],[.105,.105,.13],FUR,f"Toe_{label}_{k}",2)

# Denim shorts
ellipsoid([0,1.49,0],[.47,.24,.31],DENIM,"Shorts_Hip",3)
for label,x in [("L",-.23),("R",.23)]:
    ellipsoid([x,1.30,0],[.245,.27,.30],DENIM,f"Shorts_Leg_{label}",3)
    torus_at([x,1.08,0],.20,.022,DENIM_DARK,f"Cuff_{label}",rot=(math.pi/2,0,0),sections=20)
for label,x in [("L",-.22),("R",.22)]:
    ellipsoid([x,1.47,.285],[.13,.10,.018],DENIM_DARK,f"Pocket_{label}",2)

# Cloth shirt shell with folds
shell(1.68,2.62,.46,.38,.29,.25,SHIRT,"Shirt_Body",20,34,fold=.025)
ellipsoid([0,1.72,0],[.47,.11,.30],SHIRT,"Shirt_Hem",3)
for label,side in [("L",-1),("R",1)]:
    x=side*.46
    tube([[x,2.48,0],[side*.58,2.38,.01],[side*.63,2.27,.02]],[.21,.20,.17],SHIRT,f"Sleeve_{label}",22)
    torus_at([side*.61,2.26,.02],.145,.015,SHIRT_DARK,f"Sleeve_Seam_{label}",rot=(0,math.pi/2,0),sections=18)

# Arms and hands
for label,side in [("L",-1),("R",1)]:
    tube([[side*.62,2.30,.02],[side*.64,2.02,.04],[side*.60,1.74,.05]],[.092,.088,.095],FUR,f"Arm_{label}",20)
    ellipsoid([side*.59,1.61,.06],[.15,.18,.14],FUR,f"Hand_{label}",3)

# Cream neck
tube([[0,2.58,.02],[0,2.88,.02],[0,3.12,.01]],[.15,.145,.17],CREAM,"Neck",22)

# Sculpted feline head
def head_deform(v):
    vv=v.copy()
    front=np.clip(vv[:,2],0,1)
    vv[:,2]+=0.12*front*(1-np.abs(vv[:,1]))
    vv[:,0]*=(.96+.06*(1-np.abs(vv[:,1])))
    return vv
ellipsoid([0,3.48,.02],[.48,.44,.43],FUR,"Head",4,head_deform)
ellipsoid([-.25,3.41,.18],[.27,.24,.27],FUR,"Cheek_L",3)
ellipsoid([.25,3.41,.18],[.27,.24,.27],FUR,"Cheek_R",3)
for label,side in [("L",-1),("R",1)]:
    ellipsoid([side*.39,3.73,.02],[.18,.20,.12],FUR,f"Ear_{label}",3)
    ellipsoid([side*.39,3.73,.105],[.10,.12,.025],CREAM,f"EarInner_{label}",2)
ellipsoid([-.14,3.36,.40],[.22,.17,.20],CREAM,"Muzzle_L",3)
ellipsoid([.14,3.36,.40],[.22,.17,.20],CREAM,"Muzzle_R",3)
ellipsoid([0,3.21,.34],[.20,.15,.18],CREAM,"Chin",3)
ellipsoid([0,3.43,.56],[.12,.075,.095],NOSE,"Nose",3)
ellipsoid([0,3.48,.34],[.15,.15,.15],FUR,"SnoutBridge",3)

# Layered sunglasses
for label,side in [("L",-1),("R",1)]:
    ellipsoid([side*.22,3.57,.425],[.24,.145,.032],BLACK,f"GlassesFrame_{label}",3)
    ellipsoid([side*.22,3.57,.455],[.205,.116,.018],GLASS,f"Lens_{label}",3)
    ellipsoid([side*.17,3.61,.475],[.065,.018,.006],WHITE,f"LensShine_{label}",2)
tube([[-.04,3.57,.445],[.04,3.57,.445]],.022,BLACK,"Glasses_Bridge",12)
for label,side in [("L",-1),("R",1)]:
    tube([[side*.43,3.57,.42],[side*.52,3.56,.20]],.018,BLACK,f"GlassesTemple_{label}",12)

# Brows and hair tufts
for label,side in [("L",-1),("R",1)]:
    tube([[side*.31,3.77,.35],[side*.20,3.80,.39],[side*.11,3.77,.39]],[.025,.028,.022],BLACK,f"Brow_{label}",12)
for idx,(x0,x1) in enumerate([(-.15,-.03),(.04,.16)]):
    tube([[x0,3.87,.14],[(x0+x1)/2,3.98,.18],[x1,3.90,.18]],[.03,.035,.025],BLACK,f"Tuft_{idx}",12)

# Whiskers
for side in [-1,1]:
    for j,dy in enumerate([-.07,0,.07]):
        tube([[side*.27,3.35+dy,.49],[side*.72,3.31+dy*1.6,.53]],[.006,.003],BLACK,f"Whisker_{side}_{j}",8)

# Gold chain and pendant
for i in range(13):
    t=i/12
    ang=math.pi+t*math.pi
    x=.29*math.cos(ang)
    y=2.70+.19*math.sin(ang)
    torus_at([x,y,.285],.052,.014,GOLD,f"ChainLink_{i}",rot=(math.pi/2,0,0),sections=14)
ellipsoid([0,2.44,.30],[.075,.095,.025],GOLD,"Pendant",2)
ellipsoid([0,2.44,.327],[.021,.027,.006],BLACK,"PendantMark",2)

# Watch
torus_at([.60,1.69,.07],.11,.025,GOLD,"WatchBand",rot=(0,math.pi/2,0),sections=18)
watch=trimesh.creation.cylinder(radius=.08,height=.035,sections=24)
watch.apply_transform(trimesh.transformations.rotation_matrix(math.pi/2,[0,1,0]))
watch.apply_translation([.72,1.69,.07])
add(watch,"WatchFace",BLACK)

# Long curved tail
path=[]
N=30
for i in range(N):
    t=i/(N-1)
    x=.12+.58*math.sin(t*1.35*math.pi)
    y=1.50-.35*t+.55*t*t+.18*math.sin(t*math.pi)
    z=-.18-.55*t
    path.append([x,y,z])
tube(path,np.linspace(.11,.055,N),FUR,"Tail",24)

# Raised shirt fold details
for i,x in enumerate([-.20,.02,.22]):
    tube([[x,2.47,.265],[x*.85,2.22,.292],[x*.72,1.90,.30]],[.012,.010,.006],SHIRT_DARK,f"ShirtFold_{i}",8)

blob=scene.export(file_type="glb")
with open(OUT,"wb") as f:
    f.write(blob)
loaded=trimesh.load(OUT,force="scene")
print("Generated",OUT,"bytes",os.path.getsize(OUT),"meshes",len(loaded.geometry),"bounds",loaded.bounds)
