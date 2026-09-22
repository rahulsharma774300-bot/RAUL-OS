"""Original Rose Rail meshes, rig and clips. Run with Blender --background --python.
No source meshes, textures, animations or game artwork are used.
"""
import bpy, math, os, random
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'assets'); os.makedirs(OUT,exist_ok=True)
random.seed(31)
def mat(name,hex,metal=0,rough=.45):
    def linear(v):return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
    rgb=tuple(linear(int(hex[i:i+2],16)/255) for i in (0,2,4))
    m=bpy.data.materials.new(name); m.diffuse_color=(*rgb,1); m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=(*rgb,1); bs.inputs['Metallic'].default_value=metal; bs.inputs['Roughness'].default_value=rough
    return m
pink=mat('Rose enamel','ec397f',.15); fur=mat('Raspberry fur','f76aa2'); cream=mat('Warm ivory','ffdec6'); dark=mat('Midnight ink','20243e'); glass=mat('Teal reflective glass','328dba',.5,.18); gold=mat('Champagne gold','ffd36e',.65,.25); white=mat('Porcelain','f6eced'); teal=mat('Lagoon','35baba',.2); purple=mat('Plum','694c91'); concrete=mat('Rose sandstone','c68f9e'); leaf=mat('Mint foliage','359f90')
def clear():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def finish(o,name,m,bone=None):
    o.name=name; o.data.materials.append(m)
    if bone:
        g=o.vertex_groups.new(name=bone); g.add(list(range(len(o.data.vertices))),1,'REPLACE')
    return o
def box(name,loc,size,m,bevel=.08,bone=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object; o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Soft manufactured edges','BEVEL'); mod.width=bevel; mod.segments=3; bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL'); bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(o,name,m,bone)
def oval(name,loc,scale,m,bone=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,location=loc); o=bpy.context.object; o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for p in o.data.polygons:p.use_smooth=True
    return finish(o,name,m,bone)
def tube(name,points,radius,m,bone=None):
    cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.resolution_u=8;cu.bevel_depth=radius;cu.bevel_resolution=3
    sp=cu.splines.new('BEZIER'); sp.bezier_points.add(len(points)-1)
    for p,co in zip(sp.bezier_points,points):p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
    o=bpy.data.objects.new(name,cu);bpy.context.collection.objects.link(o);bpy.context.view_layer.objects.active=o;o.select_set(True)
    bpy.ops.object.convert(target='MESH');o=bpy.context.object;finish(o,name,m,bone);o.select_set(False);return o
def export(name,join=True):
    bpy.ops.object.select_all(action='SELECT')
    if join:
        bpy.context.view_layer.objects.active=next(o for o in bpy.context.scene.objects if o.type=='MESH'); bpy.ops.object.join()
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,name+'.glb'),export_format='GLB',export_animations=True,export_yup=True)

# Hero: angular feline ears, short muzzle, asymmetric bomber jacket and long tail.
clear()
box('Bomber jacket',(0,0,1.48),(.63,.38,.68),pink,.16,'spine')
box('Jacket hem',(0,0,1.18),(.58,.4,.12),dark,.04,'spine')
box('Ivory zipper',(0,-.207,1.5),(.026,.025,.5),gold,.008,'spine')
for s in [-1,1]:
    box('Pocket',(s*.18,-.206,1.32),(.16,.035,.1),purple,.025,'spine')
oval('Neck',(0,0,1.94),(.115,.12,.23),fur,'head')
oval('Feline head',(0,-.015,2.16),(.31,.25,.31),fur,'head')
for s in [-1,1]:
    bpy.ops.mesh.primitive_cone_add(vertices=3,radius1=.17,radius2=.025,depth=.34,location=(s*.23,0,2.43));finish(bpy.context.object,'Pointed ear',fur,'head')
    oval('Ear inset',(s*.23,-.095,2.43),(.065,.03,.1),purple,'head')
    oval('Cheek',(s*.1,-.23,2.05),(.135,.105,.09),cream,'head')
    box('Glasses frame',(s*.155,-.251,2.23),(.29,.08,.17),dark,.055,'head')
    box('Blue lens',(s*.155,-.3,2.24),(.22,.022,.105),glass,.027,'head')
    box('Lens glint',(s*.155-.04,-.315,2.265),(.08,.01,.014),white,.004,'head')
box('Glasses bridge',(0,-.29,2.24),(.08,.06,.035),gold,.01,'head')
oval('Nose',(0,-.331,2.095),(.065,.045,.043),dark,'head')
tube('Smile',[(-.1,-.303,2.0),(0,-.32,1.977),(.1,-.303,2.0)],.012,dark,'head')
oval('Cap',(0,.035,2.39),(.27,.23,.095),purple,'head')
box('Sideways cap brim',(.17,-.14,2.39),(.35,.28,.035),purple,.05,'head')
tube('Neck chain',[(-.15,-.2,1.8),(0,-.25,1.65),(.15,-.2,1.8)],.02,gold,'spine')
box('Pendant',(0,-.267,1.63),(.065,.025,.09),gold,.018,'spine')
for s,side in [(-1,'L'),(1,'R')]:
    oval('Jacket sleeve',(s*.39,0,1.63),(.14,.16,.24),pink,'arm'+side)
    oval('Forearm',(s*.46,-.005,1.31),(.085,.095,.23),fur,'fore'+side)
    oval('Paw',(s*.47,-.025,1.1),(.095,.115,.115),fur,'fore'+side)
    box('Shorts',(s*.17,0,1.02),(.28,.36,.35),dark,.07,'thigh'+side)
    oval('Shin',(s*.18,0,.52),(.087,.095,.39),fur,'shin'+side)
    box('High top sneaker',(s*.18,-.10,.14),(.25,.46,.25),cream,.09,'shin'+side)
    box('Sole',(s*.18,-.10,.047),(.265,.48,.075),dark,.025,'shin'+side)
    for j in range(3):box('Laces',(s*.18,-.22,.245+j*.018),(.14,.023,.015),purple,.005,'shin'+side)
tailpts=[(0,.19,1.13),(0,.48,1.02),(0,.79,.91),(0,1.1,1.02),(0,1.36,1.29),(0,1.48,1.58)]
for i in range(5):tube('Tail segment',tailpts[i:i+2],.065-i*.007,fur,'tail'+str(i))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
bpy.ops.object.select_all(action='DESELECT');bpy.ops.object.armature_add();rig=bpy.context.object;rig.name='Mika_Rig';bpy.ops.object.mode_set(mode='EDIT');rig.data.edit_bones.remove(rig.data.edit_bones[0])
def bone(n,h,t,parent=None):
    b=rig.data.edit_bones.new(n);b.head=h;b.tail=t
    if parent:b.parent=rig.data.edit_bones[parent]
bone('root',(0,0,0),(0,0,1))
bone('spine',(0,0,1.12),(0,0,1.82),'root');bone('head',(0,0,1.82),(0,0,2.4),'spine')
for s,side in [(-1,'L'),(1,'R')]:
    bone('arm'+side,(s*.31,0,1.77),(s*.44,0,1.45),'spine');bone('fore'+side,(s*.44,0,1.45),(s*.47,0,1.07),'arm'+side)
    bone('thigh'+side,(s*.17,0,1.14),(s*.18,0,.68),'root');bone('shin'+side,(s*.18,0,.68),(s*.18,0,.13),'thigh'+side)
for i in range(5):bone('tail'+str(i),tailpts[i],tailpts[i+1],'root' if i==0 else 'tail'+str(i-1))
bpy.ops.object.mode_set(mode='OBJECT')
for o in meshes:
    o.parent=rig;mod=o.modifiers.new('Skin','ARMATURE');mod.object=rig
# Baked skeletal clips at 30 fps. NLA strips preserve all actions in glTF.
for name,frames in [('Run',24),('Idle',60),('Jump',24),('Slide',24),('Stumble',20)]:
    rig.animation_data_create();act=bpy.data.actions.new(name);rig.animation_data.action=act
    for f in range(1,frames+2,3):
        ph=(f-1)/frames*math.tau
        for pb in rig.pose.bones:pb.rotation_mode='XYZ';pb.rotation_euler=(0,0,0);pb.location=(0,0,0)
        for side,sgn in [('L',1),('R',-1)]:
            if name=='Run':
                rig.pose.bones['thigh'+side].rotation_euler.x=.7*math.sin(ph)*sgn
                rig.pose.bones['shin'+side].rotation_euler.x=max(0,-math.sin(ph)*sgn)*1.15
                rig.pose.bones['arm'+side].rotation_euler.x=-.65*math.sin(ph)*sgn
                rig.pose.bones['fore'+side].rotation_euler.x=-.8
            elif name=='Jump':
                rig.pose.bones['thigh'+side].rotation_euler.x=-.7
                rig.pose.bones['shin'+side].rotation_euler.x=1.0
                rig.pose.bones['arm'+side].rotation_euler.x=-1.6
            elif name=='Slide':
                rig.pose.bones['thigh'+side].rotation_euler.x=-1.1
                rig.pose.bones['shin'+side].rotation_euler.x=1.7
                rig.pose.bones['spine'].rotation_euler.x=.7
                rig.pose.bones['root'].location.z=-.55
            elif name=='Stumble':rig.pose.bones['spine'].rotation_euler.x=-.3
        if name=='Run':rig.pose.bones['root'].location.z=.045*(1-math.cos(ph*2))
        if name=='Idle':rig.pose.bones['spine'].rotation_euler.y=.045*math.sin(ph)
        for i in range(5):rig.pose.bones['tail'+str(i)].rotation_euler.y=.13*math.sin(ph-i*.65)
        for pb in rig.pose.bones:
            pb.keyframe_insert('rotation_euler',frame=f);pb.keyframe_insert('location',frame=f)
    track=rig.animation_data.nla_tracks.new();track.name=name;track.strips.new(name,1,act);rig.animation_data.action=None
for p in rig.pose.bones:p.rotation_euler=(0,0,0);p.location=(0,0,0)
export('mika',False)

# Train car: rounded shell, inset doors, window surrounds, wheels and roof machinery.
clear()
box('Carriage',(0,0,1.58),(2.55,10,2.55),pink,.3)
box('Ivory roof',(0,0,2.88),(2.59,9.6,.28),cream,.14)
box('Lower skirt',(0,0,.48),(2.6,9.8,.28),dark,.08)
for s in [-1,1]:
    box('Window stripe',(s*1.279,0,2.12),(.035,9.4,.85),dark,.015)
    for y in [-3.8,-2.4,-1,1,2.4,3.8]:box('Window',(s*1.305,y,2.16),(.035,1.07,.62),glass,.12)
    for y in [-2.0,2.0]:
        box('Door',(s*1.31,y,1.54),(.04,.75,1.85),purple,.04)
        box('Door glass',(s*1.34,y,2.0),(.022,.57,.62),glass,.04)
    for y in [-3.2,3.2]:oval('Wheel',(s*1.04,y,.34),(.2,.42,.42),dark)
for y in [-5.01,5.01]:
    box('Windscreen',(0,y,2.03),(1.9,.06,1.12),dark,.22)
    box('Windshield glass',(0,y*1.008,2.07),(1.61,.04,.87),glass,.17)
    for s in [-1,1]:box('Headlight',(s*.82,y,1.22),(.32,.08,.16),cream,.05)
    box('Destination',(0,y,2.68),(1.15,.08,.18),gold,.025)
for y in [-2.5,2.5]:box('Roof vent',(0,y,3.055),(1.35,1.25,.11),purple,.05)
export('train')

for variant in range(5):
    clear();h=6+variant*1.5;wall=[pink,concrete,cream,purple,teal][variant]
    box('Townhouse',(0,0,h/2),(5.4,5,h),wall,.12)
    for z in [1,3.2,5.4,7.6,9.8]:
        if z+1>h:continue
        for x in [-1.65,0,1.65]:
            box('Window frame',(x,-2.54,z),(1.28,.18,1.68),cream,.045)
            box('Window',(x,-2.65,z),(1.02,.05,1.42),glass,.025)
            box('Mullion',(x,-2.7,z),(.06,.035,1.44),dark,.01)
        box('Floor cornice',(0,-2.6,z+1.03),(5.6,.4,.13),cream,.03)
    box('Roof cornice',(0,0,h),(5.8,5.4,.28),cream,.05)
    box('Roof water tank',(1,1,h+.6),(1.4,1.4,1.2),purple,.15)
    box('Shop sign',(0,-2.8,2.15),(4.6,.18,.58),dark,.08)
    for x in range(8):box('Striped canopy',(-2.3+x*.65,-3.05,1.72),(.65,1.15,.16),pink if x%2 else cream,.02)
    export('building'+str(variant))
clear()
box('Station canopy',(0,0,5.8),(13,11,.35),purple,.12)
for s in [-1,1]:
    box('Platform',(s*5.4,0,.22),(2.1,12,.44),cream,.08)
    for y in [-4.5,4.5]:box('Pillar',(s*5.5,y,3),(.3,.3,5.6),teal,.04)
    box('Platform edge',(s*4.4,0,.46),(.13,12,.04),gold,.01)
    box('Bench',(s*5.3,0,.8),(.65,2,.15),pink,.04)
box('Station sign',(0,4.7,5.15),(5,.2,.65),dark,.08)
export('station')
clear()
for s in [-1,1]:box('Tunnel wall',(s*5.1,0,2.9),(.8,20,5.8),purple,.12)
box('Tunnel ceiling',(0,0,6),(11,20,.8),purple,.2)
for y in [-9,-3,3,9]:
    box('Arch beam',(0,y,5.55),(10,.28,.28),pink,.08)
    for s in [-1,1]:box('Tunnel light',(s*4.55,y,3),(.08,.8,.16),cream,.02)
export('tunnel')
clear()
tube('Trunk',[(0,0,0),(.08,0,2),(.3,0,3.8)],.13,concrete)
for i in range(7):
    a=i*math.tau/7;pts=[(.3,0,3.8),(.3+math.cos(a)*.9,math.sin(a)*.9,4.1),(.3+math.cos(a)*1.65,math.sin(a)*1.65,3.45)]
    tube('Palm frond',pts,.12,leaf)
export('palm')
print('ROSE_RAIL_ART_OK')
