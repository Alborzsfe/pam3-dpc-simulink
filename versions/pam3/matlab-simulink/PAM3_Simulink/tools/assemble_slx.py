"""Structural SLX authoring, not MATLAB compilation or a Simulink execution.

The official MATLAB builder replaces these containers on START_PAM3.
This tool preserves a native R2022a OPC/XML schema from the supplied model,
removes its plant/toolbox components, and creates the documented PAM3 graph.
"""
from pathlib import Path
import copy,json,posixpath,uuid,zipfile,xml.etree.ElementTree as E

ROOT=Path(__file__).resolve().parents[1]
T=ROOT/'tools/slx_schema'
NS='http://schemas.openxmlformats.org/package/2006/relationships'
CT='http://schemas.openxmlformats.org/package/2006/content-types'

def p(parent,name,text):E.SubElement(parent,'P',Name=name).text=str(text)
def xml(root):return E.tostring(root,encoding='utf-8',xml_declaration=True)
def relations(items):
 r=E.Element('Relationships',xmlns=NS)
 for i,target,kind in items:E.SubElement(r,'Relationship',Id=i,Target=target,Type=kind)
 return xml(r)

def graph(library):
 r=E.Element('System');p(r,'Location','[0, 0, 1360, 780]');p(r,'ZoomFactor','90')
 spec=[]
 def block(kind,name,sid,ports,position,**params):
  b=E.SubElement(r,'Block',BlockType=kind,Name=name,SID=str(sid))
  p(b,'Ports',ports);p(b,'Position',position);p(b,'ZOrder',sid)
  for k,v in params.items():p(b,k,v)
  spec.append(dict(sid=str(sid),name=name,kind=kind,ports=ports))
 def line(src,dst,port=1):
  l=E.SubElement(r,'Line');p(l,'Src',f'{src}#out:1');p(l,'Dst',f'{dst}#in:{port}')
 if library:
  block('M-S-Function','PAM3_Decoder',1,'[2, 1]','[80, 70, 290, 180]',FunctionName='pam3_sfun',Parameters='pam3_cfg',DisplayMFileStacktrace='on')
  block('M-S-Function','Host_Record_Packer',2,'[3, 1]','[380, 70, 610, 180]',FunctionName='pam3_packer_sfun',Parameters='pam3_cfg',DisplayMFileStacktrace='on')
 else:
  for sid,name,var,y in [(1,'ADC_Master','pam3_input_master',90),(2,'ADC_Slave','pam3_input_slave',325),(3,'Acquisition_Command','pam3_command',560)]:
   block('FromWorkspace',name,sid,'[0, 1]',f'[45, {y}, 225, {y+45}]',VariableName=var,SampleTime='pam3_cfg.sample_time',Interpolate='off',OutputAfterFinalValue='Holding final value')
  block('M-S-Function','Master_Decoder',4,'[2, 1]','[330, 75, 580, 215]',FunctionName='pam3_sfun',Parameters='pam3_cfg',DisplayMFileStacktrace='on')
  block('M-S-Function','Slave_Decoder',5,'[2, 1]','[330, 310, 580, 450]',FunctionName='pam3_sfun',Parameters='pam3_cfg',DisplayMFileStacktrace='on')
  block('M-S-Function','Host_Record_Packer',6,'[3, 1]','[760, 185, 985, 360]',FunctionName='pam3_packer_sfun',Parameters='pam3_cfg',DisplayMFileStacktrace='on')
  for sid,name,var,pos in [(7,'Master_Trace','trace_master','[760, 60, 970, 110]'),(8,'Slave_Trace','trace_slave','[760, 440, 970, 490]'),(9,'Host_Records','trace_host','[1080, 230, 1280, 285]')]:
   block('ToWorkspace',name,sid,'[1, 0]',pos,VariableName=var,SaveFormat='Structure With Time',MaxDataPoints='inf',SampleTime='-1')
  block('Scope','ADC_Waveforms',10,'[2]','[330, 555, 410, 610]',NumInputPorts='2')
  # Group branches by source into one signal line, as native SLX requires.
  edges=[(1,4,1),(2,5,1),(3,4,2),(3,5,2),(3,6,3),(4,7,1),(5,8,1),(4,6,1),(5,6,2),(6,9,1),(1,10,1),(2,10,2)]
  for src in sorted(set(a for a,_,_ in edges)):
   dst=[(b,c) for a,b,c in edges if a==src]
   l=E.SubElement(r,'Line');p(l,'Src',f'{src}#out:1')
   if len(dst)==1:p(l,'Dst',f'{dst[0][0]}#in:{dst[0][1]}')
   else:
    for b,c in dst:p(E.SubElement(l,'Branch'),'Dst',f'{b}#in:{c}')
 return r,spec

def make(name,library=False):
 package={}
 mi=E.Element('ModelInformation',Version='1.0');m=E.SubElement(mi,'Library' if library else 'Model')
 p(m,'ModelUUID',str(uuid.uuid4()));p(m,'SLXCompressionType','Normal')
 if library:p(m,'Lock','off')
 else:
  callbacks=E.SubElement(m,'ModelCallbacks')
  p(callbacks,'InitFcn',"pam3_project_root = fileparts(fileparts(get_param(bdroot,'FileName'))); addpath(pam3_project_root,fullfile(pam3_project_root,'matlab')); pam3_prepare_model;")
 E.SubElement(m,'System',Ref='system_root')
 root,spec=graph(library);package['simulink/blockdiagram.xml']=xml(mi);package['simulink/systems/system_root.xml']=xml(root)
 package['simulink/bddefaults.xml']=xml(E.Element('BlockDiagramDefaults'))
 cfg=E.parse(T/'configSet0.xml').getroot();components=cfg.find('Object/Array')
 for element in list(components):
  if element.get('ClassName') in ['SlCovCC.ConfigComp','hdlcoderui.hdlcc','SSC.SimscapeCC']:components.remove(element)
 components.set('Dimension',f'1*{len(components)}')
 changes={'StartTime':'0','StopTime':'pam3_stop_time','FixedStep':'pam3_cfg.sample_time','SolverName':'FixedStepDiscrete','SaveTime':'off','SaveOutput':'off','SignalLogging':'off','ReturnWorkspaceOutputs':'on','SaveState':'off','LimitDataPoints':'off'}
 for element in cfg.iter('P'):
  if element.get('Name') in changes:element.text=changes[element.get('Name')]
 package['simulink/configSet0.xml']=xml(cfg)
 cs=E.Element('ConfigSetInfo');E.SubElement(cs,'ConfigSet',PartName='/simulink/configSet0.xml',Active='true').text='Configuration';package['simulink/configSetInfo.xml']=xml(cs)
 package['simulink/_rels/configSetInfo.xml.rels']=relations([('configSet0','configSet0.xml','http://schemas.mathworks.com/simulink/2014/relationships/configSet')])
 package['simulink/_rels/blockdiagram.xml.rels']=relations([('system_root','systems/system_root.xml','http://schemas.mathworks.com/simulink/2010/relationships/system')])
 for n in ['mwcoreProperties.xml','mwcorePropertiesReleaseInfo.xml']:
  package['metadata/'+n]=(T/n).read_bytes()
 ext=E.Element('mwcoreProperties',xmlns='http://schemas.mathworks.com/package/2014/corePropertiesExtension');E.SubElement(ext,'uuid').text=str(uuid.uuid4());package['metadata/mwcorePropertiesExtension.xml']=xml(ext)
 core=E.Element('cp:coreProperties',{'xmlns:cp':'http://schemas.openxmlformats.org/package/2006/metadata/core-properties','xmlns:dc':'http://purl.org/dc/elements/1.1/'})
 E.SubElement(core,'dc:title').text=name;E.SubElement(core,'dc:description').text='Structurally authored model. Rebuild via build_pam3_models in MATLAB; Simulink execution pending.'
 package['metadata/coreProperties.xml']=xml(core)
 rootrel=[('blockDiagram','simulink/blockdiagram.xml','http://schemas.mathworks.com/simulink/2010/relationships/blockDiagram'),('blockDiagramDefaults','simulink/bddefaults.xml','http://schemas.mathworks.com/simulink/2017/relationships/blockDiagramDefaults'),('configSetInfo','simulink/configSetInfo.xml','http://schemas.mathworks.com/simulink/2014/relationships/configSetInfo'),('rId1','metadata/mwcoreProperties.xml','http://schemas.mathworks.com/package/2012/relationships/coreProperties'),('rId2','metadata/mwcorePropertiesExtension.xml','http://schemas.mathworks.com/package/2014/relationships/corePropertiesExtension'),('rId3','metadata/mwcorePropertiesReleaseInfo.xml','http://schemas.mathworks.com/package/2019/relationships/corePropertiesReleaseInfo'),('rId4','metadata/coreProperties.xml','http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties')]
 package['_rels/.rels']=relations(rootrel)
 types=E.Element('Types',xmlns=CT)
 E.SubElement(types,'Default',Extension='rels',ContentType='application/vnd.openxmlformats-package.relationships+xml')
 E.SubElement(types,'Default',Extension='xml',ContentType='application/vnd.mathworks.simulink.mdl+xml')
 for part,content in [('metadata/coreProperties.xml','application/vnd.openxmlformats-package.core-properties+xml'),('metadata/mwcoreProperties.xml','application/vnd.mathworks.package.coreProperties+xml'),('metadata/mwcorePropertiesExtension.xml','application/vnd.mathworks.package.corePropertiesExtension+xml'),('metadata/mwcorePropertiesReleaseInfo.xml','application/vnd.mathworks.package.corePropertiesReleaseInfo+xml'),('simulink/configSet0.xml','application/vnd.mathworks.simulink.configSet+xml'),('simulink/configSetInfo.xml','application/vnd.mathworks.simulink.configSetInfo+xml')]:E.SubElement(types,'Override',PartName='/'+part,ContentType=content)
 package['[Content_Types].xml']=xml(types)
 destination=ROOT/'models'/(name+'.slx')
 with zipfile.ZipFile(destination,'w',zipfile.ZIP_DEFLATED) as z:
  for path,content in package.items():z.writestr(path,content)
 return dict(model=name,blocks=spec,authoring='OPC/XML structure; not saved or compiled in MATLAB')

def main():
 report=[make('pam3_patent_demo'),make('pam3_patent_blocks',True)]
 (ROOT/'validation/model_graph.json').write_text(json.dumps(report,indent=2))
 print(json.dumps({'models_created':[r['model'] for r in report],'matlab_compiled':False},indent=2))
if __name__=='__main__':main()
