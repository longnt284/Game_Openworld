"""Compare exported assets against the committed gameplay contracts (standard library only)."""
import json
import math
import struct
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from asset_manifest import model_stats

def glb(data):
    size=struct.unpack_from('<I',data,12)[0]
    doc=json.loads(data[20:20+size])
    return doc,data[28+size:]

def values(doc, binary, index):
    a=doc['accessors'][index]
    view=doc['bufferViews'][a['bufferView']]
    fmt={5120:'b',5121:'B',5122:'h',5123:'H',5125:'I',5126:'f'}[a['componentType']]
    width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
    size=struct.calcsize('<'+fmt*width)
    start=view.get('byteOffset',0)+a.get('byteOffset',0)
    return [struct.unpack_from('<'+fmt*width,binary,start+i*view.get('byteStride',size)) for i in range(a['count'])]

def near(a,b):
    return len(a)==len(b) and all(len(x)==len(y) and all(abs(v-w)<0.00002 for v,w in zip(x,y)) for x,y in zip(a,b))

def animation_data(doc,binary):
    out={}
    for clip in doc.get('animations',[]):
        channels={}
        for ch in clip['channels']:
            s=clip['samplers'][ch['sampler']]
            key=(doc['nodes'][ch['target']['node']]['name'],ch['target']['path'])
            channels[key]=(values(doc,binary,s['input']),values(doc,binary,s['output']))
        out[clip['name']]=channels
    return out

def colliders(doc,binary):
    result={}
    for node in doc.get('nodes',[]):
        if 'colonly' not in node.get('name',''):
            continue
        pos=[]
        for p in doc['meshes'][node['mesh']]['primitives']:
            pos+=values(doc,binary,p['attributes']['POSITION'])
        result[node['name']]=(sorted(pos),{k:node[k] for k in ('translation','rotation','scale','matrix') if k in node})
    return result

base = sys.argv[1] if len(sys.argv) > 1 else '08d13b701a4cccb415b888339a1b0bdd7743bc98'
results=[]
errors=[]
for path in sorted((ROOT/'assets/models').rglob('*.glb')):
    relative=path.relative_to(ROOT).as_posix()
    previous=subprocess.run(['git','show',base+':'+relative],cwd=ROOT,capture_output=True)
    if previous.returncode:
        continue
    current=path.read_bytes()
    if current==previous.stdout:
        continue
    old,ob=glb(previous.stdout)
    new,nb=glb(current)
    try:
        oa,na=animation_data(old,ob),animation_data(new,nb)
        assert oa.keys()==na.keys(),'animation names changed'
        for name in oa:
            assert oa[name].keys()==na[name].keys(),name+' bone tracks changed'
            for key in oa[name]:
                assert all(near(a,b) for a,b in zip(oa[name][key],na[name][key])),name+' timing/pose changed'
        oc,nc=colliders(old,ob),colliders(new,nb)
        assert oc.keys()==nc.keys(),'collider names changed'
        for name in oc:
            assert near(oc[name][0],nc[name][0]) and oc[name][1]==nc[name][1],name+' collider changed'
        for skin in new.get('skins',[]):
            old_skin=next(s for s in old['skins'] if s.get('name')==skin.get('name'))
            assert [new['nodes'][i]['name'] for i in skin['joints']]==[old['nodes'][i]['name'] for i in old_skin['joints']],'skeleton changed'
            assert near(values(new,nb,skin['inverseBindMatrices']),values(old,ob,old_skin['inverseBindMatrices'])),'bind pose changed'
        for mesh in new.get('meshes',[]):
            for p in mesh['primitives']:
                assert all(math.isfinite(x) for v in values(new,nb,p['attributes']['POSITION']) for x in v),'nonfinite mesh'
                if 'WEIGHTS_0' in p['attributes']:
                    assert all(abs(sum(w)-1)<0.001 for w in values(new,nb,p['attributes']['WEIGHTS_0'])),'unweighted vertices'
        for node in new.get('nodes',[]):
            assert all(x>0 for x in node.get('scale',[1,1,1])),'negative/zero scale'
        stats=model_stats(path)
        results.append(dict(file=relative,**stats))
    except AssertionError as error:
        errors.append(relative+': '+str(error))
out=ROOT/'docs/visual-upgrade/asset-validation.json'
out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps({'assets':results,'errors':errors},ensure_ascii=False,indent=2),encoding='utf-8')
print(f'ART CONTRACT: {len(results)} changed assets passed; {len(errors)} errors')
for error in errors:
    print(error)
sys.exit(bool(errors))
