"""Portable SLX container authoring, NOT MATLAB compilation/execution.

build_dpc_replay_model is the authoritative native builder and is run by START.
This file creates a browsable graph with the same default parameters.
"""
from pathlib import Path
import uuid, json, copy, zipfile, xml.etree.ElementTree as E

ROOT = Path(__file__).resolve().parents[1]
SCHEMA = ROOT/'tools/slx_schema'
NS = 'http://schemas.openxmlformats.org/package/2006/relationships'
CT = 'http://schemas.openxmlformats.org/package/2006/content-types'


def p(parent, name, value):
    E.SubElement(parent, 'P', Name=name).text = str(value)


def xml(root): return E.tostring(root, encoding='utf-8', xml_declaration=True)


def rels(entries):
    root = E.Element('Relationships', xmlns=NS)
    for name, target, kind in entries:
        E.SubElement(root, 'Relationship', Id=name, Target=target, Type=kind)
    return xml(root)


def graph():
    root = E.Element('System'); p(root,'Location','[0, 0, 960, 1080]'); p(root,'ZoomFactor',90)
    specs, edges, subs = [], [], {}
    next_sid = 0

    def block(kind, name, ports, position, parent=root, **parameters):
        nonlocal next_sid
        next_sid += 1; sid = next_sid
        b = E.SubElement(parent, 'Block', BlockType=kind, Name=name, SID=str(sid))
        p(b,'Ports',ports); p(b,'Position',position); p(b,'ZOrder',sid)
        for key, value in parameters.items(): p(b,key,value)
        specs.append(dict(sid=str(sid),name=name,kind=kind,parameters=parameters))
        return b, sid

    def source(name, var, pos):
        return block('FromWorkspace',name,'[0, 1]',pos,VariableName=var,
                     SampleTime='dpc_replay_cfg.sample_time',Interpolate='off',
                     OutputAfterFinalValue='Holding final value')[1]

    def sink(name, var, pos):
        return block('ToWorkspace',name,'[1, 0]',pos,VariableName=var,
                     SaveFormat='Structure With Time',MaxDataPoints='inf',Decimation=1,SampleTime=-1)[1]

    def relay(name, pos, parent=root, on=1, off=-1):
        return block('Relay',name,'[1, 1]',pos,parent=parent,OnSwitchValue=on,OffSwitchValue=off,
                     OnOutputValue=1,OffOutputValue=0,SampleTime='dpc_replay_cfg.sample_time')[1]

    def lines(system, line_edges):
        for source_sid in sorted(set(a for a, _, _ in line_edges)):
            line = E.SubElement(system,'Line'); p(line,'Src',f'{source_sid}#out:1')
            destinations=[(b,c) for a,b,c in line_edges if a==source_sid]
            if len(destinations)==1:
                p(line,'Dst',f'{destinations[0][0]}#in:{destinations[0][1]}')
            else:
                for b,c in destinations: p(E.SubElement(line,'Branch'),'Dst',f'{b}#in:{c}')

    def ternary(name, pos):
        sub, sid = block('SubSystem',name,'[1, 1]',pos)
        reference = f'system_{sid}'
        E.SubElement(sub,'System',Ref=reference)
        system = E.Element('System'); p(system,'Location','[0, 0, 650, 300]')
        i = block('Inport','Error','[0, 1]','[25, 108, 55, 122]',parent=system,Port=1)[1]
        center = block('Bias','Center_Error','[1, 1]','[95, 95, 155, 135]',parent=system,Bias=0)[1]
        reverse = block('Gain','Reverse_Sign','[1, 1]','[210, 165, 260, 205]',parent=system,Gain=-1)[1]
        positive = relay('Positive_State','[300, 45, 405, 95]',parent=system,on=1,off=.5)
        negative = relay('Negative_State','[300, 165, 405, 215]',parent=system,on=1,off=.5)
        total = block('Sum','Three_Level_Output','[2, 1]','[465, 103, 485, 147]',parent=system,Inputs='+-')[1]
        o = block('Outport','Decision','[1, 0]','[545, 118, 575, 132]',parent=system,Port=1)[1]
        lines(system,[(i,center,1),(center,positive,1),(center,reverse,1),(reverse,negative,1),
                      (positive,total,1),(negative,total,2),(total,o,1)])
        subs[reference]=system
        return sid

    patent_sids = []
    for ch,label in enumerate(['P','Q']):
        y=60+390*ch
        error=source('Error_'+label,'dpc_error_'+label,f'[40, {y}, 215, {y+45}]')
        adc=source('ADC_'+label,'dpc_adc_'+label,f'[40, {y+195}, 215, {y+240}]')
        binary=relay('Binary_'+label,f'[320, {y}, 490, {y+55}]')
        tri=ternary('Control_Ternary_'+label,f'[320, {y+90}, 535, {y+155}]')
        patent=block('M-S-Function','Patent_'+label,'[2, 1]',f'[320, {y+195}, 535, {y+275}]',
                     FunctionName='pam3_sfun',Parameters='dpc_patent_cfg',DisplayMFileStacktrace='on')[1]
        patent_sids.append(patent)
        bl=sink('Binary_'+label+'_Log','dpc_binary_'+label,f'[660, {y}, 850, {y+45}]')
        tl=sink('Ternary_'+label+'_Log','dpc_ternary_'+label,f'[660, {y+90}, 850, {y+135}]')
        pl=sink('Patent_'+label+'_Log','dpc_patent_'+label,f'[660, {y+215}, 850, {y+260}]')
        edges.extend([(error,binary,1),(error,tri,1),(adc,patent,1),(binary,bl,1),(tri,tl,1),(patent,pl,1)])
    command=source('Capture_Command','dpc_command','[40, 835, 215, 880]')
    edges.extend((command, sid, 2) for sid in patent_sids)
    lines(root, edges)
    return root, subs, specs


def main():
    package={}
    model = E.Element('ModelInformation',Version='1.0')
    m=E.SubElement(model,'Model'); p(m,'ModelUUID',str(uuid.uuid4()));p(m,'SLXCompressionType','Normal')
    callbacks=E.SubElement(m,'ModelCallbacks')
    p(callbacks,'InitFcn',"dpc_project_root=fileparts(fileparts(get_param(bdroot,'FileName'))); addpath(dpc_project_root,fullfile(dpc_project_root,'matlab'),fullfile(dpc_project_root,'patent_core')); dpc_prepare_replay_model;")
    E.SubElement(m,'System',Ref='system_root')
    root, subs, specs=graph()
    package['simulink/blockdiagram.xml']=xml(model)
    package['simulink/systems/system_root.xml']=xml(root)
    for ref, system in subs.items():package[f'simulink/systems/{ref}.xml']=xml(system)
    package['simulink/bddefaults.xml']=xml(E.Element('BlockDiagramDefaults'))
    config=E.parse(SCHEMA/'configSet0.xml').getroot()
    components=config.find('Object/Array')
    for component in list(components):
        if component.get('ClassName') in ['SlCovCC.ConfigComp','hdlcoderui.hdlcc','SSC.SimscapeCC']:
            components.remove(component)
    components.set('Dimension',f'1*{len(components)}')
    changes=dict(StartTime='0',StopTime='dpc_replay_stop',FixedStep='dpc_replay_cfg.sample_time',
                 SolverName='FixedStepDiscrete',SaveTime='off',SaveOutput='off',SignalLogging='off',
                 ReturnWorkspaceOutputs='on',SaveState='off',LimitDataPoints='off')
    for el in config.iter('P'):
        if el.get('Name') in changes:el.text=changes[el.get('Name')]
    package['simulink/configSet0.xml']=xml(config)
    info=E.Element('ConfigSetInfo')
    E.SubElement(info,'ConfigSet',PartName='/simulink/configSet0.xml',Active='true').text='Configuration'
    package['simulink/configSetInfo.xml']=xml(info)
    package['simulink/_rels/configSetInfo.xml.rels']=rels([('configSet0','configSet0.xml','http://schemas.mathworks.com/simulink/2014/relationships/configSet')])
    refs=[('system_root','systems/system_root.xml','http://schemas.mathworks.com/simulink/2010/relationships/system')]
    package['simulink/_rels/blockdiagram.xml.rels']=rels(refs)
    package['simulink/systems/_rels/system_root.xml.rels']=rels([
        (ref,f'{ref}.xml','http://schemas.mathworks.com/simulink/2010/relationships/system') for ref in subs])
    for name in ['mwcoreProperties.xml','mwcorePropertiesReleaseInfo.xml']:
        package['metadata/'+name]=(SCHEMA/name).read_bytes()
    extension=E.Element('mwcoreProperties',xmlns='http://schemas.mathworks.com/package/2014/corePropertiesExtension')
    E.SubElement(extension,'uuid').text=str(uuid.uuid4())
    package['metadata/mwcorePropertiesExtension.xml']=xml(extension)
    core=E.Element('cp:coreProperties',{'xmlns:cp':'http://schemas.openxmlformats.org/package/2006/metadata/core-properties','xmlns:dc':'http://purl.org/dc/elements/1.1/'})
    E.SubElement(core,'dc:title').text='dpc_same_input_comparison'
    E.SubElement(core,'dc:description').text='Structurally authored comparison graph; rebuild natively via build_dpc_replay_model. No Simulink execution claimed.'
    package['metadata/coreProperties.xml']=xml(core)
    entries=[('blockDiagram','simulink/blockdiagram.xml','http://schemas.mathworks.com/simulink/2010/relationships/blockDiagram'),
             ('blockDiagramDefaults','simulink/bddefaults.xml','http://schemas.mathworks.com/simulink/2017/relationships/blockDiagramDefaults'),
             ('configSetInfo','simulink/configSetInfo.xml','http://schemas.mathworks.com/simulink/2014/relationships/configSetInfo'),
             ('rId1','metadata/mwcoreProperties.xml','http://schemas.mathworks.com/package/2012/relationships/coreProperties'),
             ('rId2','metadata/mwcorePropertiesExtension.xml','http://schemas.mathworks.com/package/2014/relationships/corePropertiesExtension'),
             ('rId3','metadata/mwcorePropertiesReleaseInfo.xml','http://schemas.mathworks.com/package/2019/relationships/corePropertiesReleaseInfo'),
             ('rId4','metadata/coreProperties.xml','http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties')]
    package['_rels/.rels']=rels(entries)
    types=E.Element('Types',xmlns=CT)
    E.SubElement(types,'Default',Extension='rels',ContentType='application/vnd.openxmlformats-package.relationships+xml')
    E.SubElement(types,'Default',Extension='xml',ContentType='application/vnd.mathworks.simulink.mdl+xml')
    for name, content in [('metadata/coreProperties.xml','application/vnd.openxmlformats-package.core-properties+xml'),
                          ('metadata/mwcoreProperties.xml','application/vnd.mathworks.package.coreProperties+xml'),
                          ('metadata/mwcorePropertiesExtension.xml','application/vnd.mathworks.package.corePropertiesExtension+xml'),
                          ('metadata/mwcorePropertiesReleaseInfo.xml','application/vnd.mathworks.package.corePropertiesReleaseInfo+xml'),
                          ('simulink/configSet0.xml','application/vnd.mathworks.simulink.configSet+xml'),
                          ('simulink/configSetInfo.xml','application/vnd.mathworks.simulink.configSetInfo+xml')]:
        E.SubElement(types,'Override',PartName='/'+name,ContentType=content)
    package['[Content_Types].xml']=xml(types)
    file=ROOT/'models/dpc_same_input_comparison.slx'
    with zipfile.ZipFile(file,'w',zipfile.ZIP_DEFLATED) as z:
        for name, content in package.items():z.writestr(name,content)
    # Structural checks: every internal system reference and relationship target exists.
    all_sids=[s['sid'] for s in specs];assert len(all_sids)==len(set(all_sids))
    for system in [root,*subs.values()]:
        local={b.get('SID') for b in system.findall('Block')}
        for line in system.findall('Line'):
            ports=[p.text for p in line.iter('P') if p.get('Name') in ['Src','Dst']]
            assert all(port.split('#')[0] in local for port in ports)
    owner_rels=E.fromstring(package['simulink/systems/_rels/system_root.xml.rels'])
    owners={r.get('Id'):r.get('Target') for r in owner_rels}
    for reference in root.findall('Block/System'):
        ref=reference.get('Ref')
        assert ref in owners and 'simulink/systems/'+owners[ref] in package
    report=dict(model='dpc_same_input_comparison',authoring='OPC/XML; native builder authoritative',
                blocks=specs,subsystems=len(subs),zip_crc_ok=True,system_references_ok=True,
                matlab_loaded=False,simulink_executed=False)
    (ROOT/'validation/model_structure.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='blocks'},indent=2))


if __name__=='__main__':main()
