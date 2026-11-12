"""One graph specification for the native MATLAB builder and draft SLX.

The draft SLX is structurally authored, NOT MATLAB-saved or Simulink-tested.
START_SIMULINK_COMPARE rebuilds it using documented APIs on the user's MATLAB.
"""
from pathlib import Path
import json
import uuid
import zipfile
import xml.etree.ElementTree as E
from collections import defaultdict

ROOT = Path(__file__).resolve().parents[1]
SOURCES = {
    "FromWorkspace": "simulink/Sources/From Workspace",
    "ToWorkspace": "simulink/Sinks/To Workspace",
    "Scope": "simulink/Sinks/Scope",
    "SubSystem": "built-in/SubSystem",
    "Relay": "simulink/Discontinuities/Relay",
    "Bias": "simulink/Math Operations/Bias",
    "Gain": "simulink/Math Operations/Gain",
    "Math": "simulink/Math Operations/Math Function",
    "Mux": "simulink/Signal Routing/Mux",
    "Demux": "simulink/Signal Routing/Demux",
    "Constant": "simulink/Sources/Constant",
    "Switch": "simulink/Signal Routing/Switch",
    "UnitDelay": "simulink/Discrete/Unit Delay",
    "Inport": "simulink/Ports & Subsystems/In1",
    "Outport": "simulink/Ports & Subsystems/Out1",
    "M-S-Function": "built-in/M-S-Function",
    "Terminator": "simulink/Sinks/Terminator",
}
CALLBACK = (
    "simple_root=fileparts(fileparts(get_param(bdroot,'FileName'))); "
    "addpath(simple_root,fullfile(simple_root,'PAM3_original'),"
    "fullfile(simple_root,'simulink')); prepare_simulink_comparison(bdroot);"
)


def graph():
    systems = []
    sid = 0

    def system(key):
        s = {"id": key, "blocks": [], "lines": [], "notes": []}
        systems.append(s)
        return s

    def block(s, kind, name, pos, ports, child="", **params):
        nonlocal sid
        sid += 1
        s["blocks"].append(dict(
            type=kind, source=SOURCES[kind], name=name, position=pos,
            ports=ports, params=params, subsystem=child, sid=sid,
        ))

    def line(s, src, dst, sp=1, dp=1, name=""):
        s["lines"].append(dict(src=src, srcPort=sp, dst=dst, dstPort=dp, name=name))

    def note(s, text, pos):
        s["notes"].append(dict(text=text, position=pos))

    top = system("root")
    note(top, "HYSTERESIS vs ORIGINAL PAM3 | identical clean and noisy inputs", [40, 15])
    note(top, "Double-click a test subsystem to inspect its blocks. Scope vector order: Hysteresis, PAM3.", [40, 42])
    for case, y in [("Clean", 105), ("Noisy", 415)]:
        key = case.lower()
        block(top, "FromWorkspace", case+"_ADC", [40, y+35, 195, y+85], [0, 1],
              VariableName="simple_adc_"+key, Interpolate="off",
              SampleTime="simple_ts", OutputAfterFinalValue="Holding final value")
        block(top, "SubSystem", case+"_Test", [270, y, 535, y+215], [1, 3], key+"_test")
        line(top, case+"_ADC", case+"_Test")
        for label, offset, port, variable in [
            ("Levels", 0, 1, "levels_"+key),
            ("Power", 95, 2, "power_"+key),
        ]:
            block(top, "Scope", case+"_"+label+"_Scope", [650, y+offset, 730, y+offset+55], [1, 0])
            block(top, "ToWorkspace", case+"_"+label+"_Log", [850, y+offset, 1040, y+offset+45], [1, 0],
                  VariableName=variable, SaveFormat="Array", MaxDataPoints="inf",
                  Decimation="1", SampleTime="-1")
            line(top, case+"_Test", case+"_"+label+"_Scope", port)
            line(top, case+"_Test", case+"_"+label+"_Log", port)
        block(top, "ToWorkspace", case+"_ADC_Trace_Log", [650, y+185, 850, y+230], [1, 0],
              VariableName="debug_"+key, SaveFormat="Array", MaxDataPoints="inf",
              Decimation="1", SampleTime="-1")
        line(top, case+"_Test", case+"_ADC_Trace_Log", 3)
    note(top, "Power is hypothetical: 1 V per level, R=1 ohm by default, p=v^2/R. Binary +/-1 necessarily gives constant power.", [40, 770])
    note(top, "START_SIMULINK_COMPARE: build -> run -> compare actual logged samples with MATLAB -> calculate THD and ripple.", [40, 805])

    for case in ["Clean", "Noisy"]:
        key = case.lower()
        s = system(key+"_test")
        block(s, "Inport", "ADC", [35, 165, 65, 185], [0, 1], Port="1")
        block(s, "Bias", "Remove_ADC_Offset", [115, 55, 225, 100], [1, 1],
              Bias="-simple_cfg.adc_center")
        block(s, "Gain", "Normalize_ADC", [275, 55, 355, 100], [1, 1],
              Gain="1/simple_cfg.adc_gain")
        block(s, "Relay", "Hysteresis", [410, 40, 535, 110], [1, 1],
              OnSwitchValue="simple_cfg.hysteresis_on",
              OffSwitchValue="simple_cfg.hysteresis_off",
              OnOutputValue="1", OffOutputValue="-1")
        block(s, "SubSystem", "PAM3_Detector", [240, 225, 535, 335], [1, 2],
              key+"_pam3")
        block(s, "Mux", "Levels_H_then_PAM3", [635, 60, 640, 250], [2, 1], Inputs="2")
        block(s, "Outport", "Levels_H_PAM3", [900, 145, 930, 165], [1, 0], Port="1")
        for label, y in [("H", 400), ("PAM3", 510)]:
            block(s, "Gain", label+"_Level_to_Volts", [240, y, 350, y+45], [1, 1],
                  Gain="simple_cfg.output_volts_per_level")
            block(s, "Math", label+"_Voltage_Squared", [410, y, 500, y+45], [1, 1],
                  Operator="square")
            block(s, "Gain", label+"_Divide_by_R", [550, y, 650, y+45], [1, 1],
                  Gain="1/simple_cfg.resistance_ohm")
            line(s, label+"_Level_to_Volts", label+"_Voltage_Squared")
            line(s, label+"_Voltage_Squared", label+"_Divide_by_R")
        block(s, "Mux", "Power_H_then_PAM3", [760, 400, 765, 555], [2, 1], Inputs="2")
        block(s, "Outport", "Power_H_PAM3_W", [900, 470, 930, 490], [1, 0], Port="2")
        block(s, "Mux", "ADC_and_Trace", [635, 275, 640, 350], [2, 1], Inputs="2")
        block(s, "Outport", "ADC_and_18_Trace_Values", [900, 305, 930, 325], [1, 0], Port="3")
        line(s, "ADC", "Remove_ADC_Offset")
        line(s, "Remove_ADC_Offset", "Normalize_ADC")
        line(s, "Normalize_ADC", "Hysteresis")
        line(s, "ADC", "PAM3_Detector")
        line(s, "Hysteresis", "Levels_H_then_PAM3")
        line(s, "PAM3_Detector", "Levels_H_then_PAM3", dp=2)
        line(s, "Levels_H_then_PAM3", "Levels_H_PAM3")
        line(s, "Hysteresis", "H_Level_to_Volts")
        line(s, "PAM3_Detector", "PAM3_Level_to_Volts")
        line(s, "H_Divide_by_R", "Power_H_then_PAM3")
        line(s, "PAM3_Divide_by_R", "Power_H_then_PAM3", dp=2)
        line(s, "Power_H_then_PAM3", "Power_H_PAM3_W")
        line(s, "ADC", "ADC_and_Trace")
        line(s, "PAM3_Detector", "ADC_and_Trace", sp=2, dp=2)
        line(s, "ADC_and_Trace", "ADC_and_18_Trace_Values")
        note(s, "Both branches use the SAME 8-bit ADC sample. Top: native Relay. Bottom: original PAM3 receiver.", [35, 5])
        note(s, "Levels are dimensionless. Only the lower power branches convert them to hypothetical volts.", [35, 650])

        p = system(key+"_pam3")
        block(p, "Inport", "ADC", [35, 115, 65, 135], [0, 1], Port="1")
        block(p, "Constant", "Real_Sample_Command", [35, 210, 170, 250], [0, 1],
              Value="1", SampleTime="simple_ts")
        block(p, "M-S-Function", "Original_Decoder", [235, 95, 445, 245], [2, 1],
              FunctionName="pam3_sfun", Parameters="simple_pam3_cfg")
        block(p, "Demux", "Valid_Symbol_Debug", [505, 105, 510, 250], [1, 3],
              Outputs="[1 1 16]")
        block(p, "Terminator", "Unused_Debug_Fields", [575, 245, 595, 265], [1, 0])
        block(p, "Switch", "Update_Only_When_Valid", [680, 95, 745, 185], [3, 1],
              Criteria="u2 >= Threshold", Threshold="0.5")
        block(p, "UnitDelay", "Last_Valid_Symbol", [675, 310, 785, 355], [1, 1],
              InitialCondition="0", SampleTime="simple_ts")
        block(p, "Outport", "Held_Symbol", [885, 130, 915, 150], [1, 0], Port="1")
        block(p, "Outport", "Trace_18_Values", [885, 410, 915, 430], [1, 0], Port="2")
        line(p, "ADC", "Original_Decoder")
        line(p, "Real_Sample_Command", "Original_Decoder", dp=2)
        line(p, "Original_Decoder", "Valid_Symbol_Debug")
        line(p, "Valid_Symbol_Debug", "Update_Only_When_Valid", sp=2)
        line(p, "Valid_Symbol_Debug", "Update_Only_When_Valid", sp=1, dp=2)
        line(p, "Valid_Symbol_Debug", "Unused_Debug_Fields", sp=3)
        line(p, "Last_Valid_Symbol", "Update_Only_When_Valid", dp=3)
        line(p, "Update_Only_When_Valid", "Last_Valid_Symbol")
        line(p, "Update_Only_When_Valid", "Held_Symbol")
        line(p, "Original_Decoder", "Trace_18_Values")
        note(p, "ORIGINAL PAM3: ADC -> slope / four thresholds -> spike filter -> edges / timing -> valid symbol", [35, 15])
        note(p, "The original receiver is a stateful Level-2 MATLAB S-function. Open pam3_step.m to inspect its full algorithm.", [35, 48])
        note(p, "Switch + Unit Delay explicitly hold the last valid symbol. Original processing latency is preserved.", [35, 475])
    return dict(
        model="hysteresis_pam3_compare", systems=systems, callback=CALLBACK,
        matlab_compiled=False, simulink_executed=False,
    )


def prop(parent, name, value):
    E.SubElement(parent, "P", Name=name).text = str(value)


def xml(element):
    return E.tostring(element, encoding="utf-8", xml_declaration=True)


def relations(items):
    r = E.Element("Relationships", xmlns="http://schemas.openxmlformats.org/package/2006/relationships")
    for key, target, kind in items:
        E.SubElement(r, "Relationship", Id=key, Target=target, Type=kind)
    return xml(r)


def make_slx(spec):
    pkg = {}
    modelinfo = E.Element("ModelInformation", Version="1.0")
    model = E.SubElement(modelinfo, "Model")
    prop(model, "ModelUUID", str(uuid.uuid4()))
    prop(model, "SLXCompressionType", "Normal")
    callbacks = E.SubElement(model, "ModelCallbacks")
    for name in ["PostLoadFcn", "InitFcn"]:
        prop(callbacks, name, spec["callback"])
    E.SubElement(model, "System", Ref="system_root")
    pkg["simulink/blockdiagram.xml"] = xml(modelinfo)
    sys_rel = "http://schemas.mathworks.com/simulink/2010/relationships/system"
    annotation_sid = 1+max(b["sid"] for s in spec["systems"] for b in s["blocks"])
    for system in spec["systems"]:
        r = E.Element("System")
        prop(r, "Location", "[0, 0, 1150, 900]")
        prop(r, "ZoomFactor", "85")
        ids = {}
        childrels = []
        for b in system["blocks"]:
            ids[b["name"]] = b["sid"]
            element = E.SubElement(r, "Block", BlockType=b["type"], Name=b["name"], SID=str(b["sid"]))
            prop(element, "Ports", "["+", ".join(map(str, b["ports"]))+"]")
            prop(element, "Position", "["+", ".join(map(str, b["position"]))+"]")
            prop(element, "ZOrder", b["sid"])
            for k, v in b["params"].items():
                prop(element, k, v)
            if b["subsystem"]:
                ref = "system_"+b["subsystem"]
                E.SubElement(element, "System", Ref=ref)
                childrels.append((ref, ref+".xml", sys_rel))
        lines = defaultdict(list)
        for edge in system["lines"]:
            lines[(edge["src"], edge["srcPort"])].append(edge)
        for (src, sp), edges in lines.items():
            line = E.SubElement(r, "Line")
            prop(line, "Src", f"{ids[src]}#out:{sp}")
            for edge in edges:
                target = line if len(edges) == 1 else E.SubElement(line, "Branch")
                prop(target, "Dst", f"{ids[edge['dst']]}#in:{edge['dstPort']}")
        for k, n in enumerate(system["notes"], 1):
            a = E.SubElement(r, "Annotation", SID=str(annotation_sid))
            annotation_sid += 1
            prop(a, "Name", n["text"])
            prop(a, "Position", "["+", ".join(map(str, n["position"]))+"]")
        filename = "system_"+system["id"]+".xml"
        pkg["simulink/systems/"+filename] = xml(r)
        if childrels:
            pkg["simulink/systems/_rels/"+filename+".rels"] = relations(childrels)
    pkg["simulink/bddefaults.xml"] = xml(E.Element("BlockDiagramDefaults"))
    template = ROOT/"tools/slx_schema"
    cfg = E.parse(template/"configSet0.xml").getroot()
    components = cfg.find("Object/Array")
    for item in list(components):
        if item.get("ClassName") in ["SlCovCC.ConfigComp", "hdlcoderui.hdlcc", "SSC.SimscapeCC"]:
            components.remove(item)
    components.set("Dimension", f"1*{len(components)}")
    changes = dict(
        StartTime="0", StopTime="simple_stop_time", FixedStep="simple_ts",
        SolverName="FixedStepDiscrete", SaveTime="on", TimeSaveName="simple_time",
        SaveFormat="Array", SaveOutput="off", SignalLogging="off",
        ReturnWorkspaceOutputs="on", SaveState="off", LimitDataPoints="off",
    )
    for p in cfg.iter("P"):
        if p.get("Name") in changes:
            p.text = changes[p.get("Name")]
    pkg["simulink/configSet0.xml"] = xml(cfg)
    cs = E.Element("ConfigSetInfo")
    E.SubElement(cs, "ConfigSet", PartName="/simulink/configSet0.xml", Active="true").text = "Configuration"
    pkg["simulink/configSetInfo.xml"] = xml(cs)
    pkg["simulink/_rels/configSetInfo.xml.rels"] = relations([
        ("configSet0", "configSet0.xml", "http://schemas.mathworks.com/simulink/2014/relationships/configSet")
    ])
    pkg["simulink/_rels/blockdiagram.xml.rels"] = relations([
        ("system_root", "systems/system_root.xml", sys_rel)
    ])
    for name in ["mwcoreProperties.xml", "mwcorePropertiesReleaseInfo.xml"]:
        pkg["metadata/"+name] = (template/name).read_bytes()
    extension = E.Element("mwcoreProperties", xmlns="http://schemas.mathworks.com/package/2014/corePropertiesExtension")
    E.SubElement(extension, "uuid").text = str(uuid.uuid4())
    pkg["metadata/mwcorePropertiesExtension.xml"] = xml(extension)
    core = E.Element("cp:coreProperties", {
        "xmlns:cp": "http://schemas.openxmlformats.org/package/2006/metadata/core-properties",
        "xmlns:dc": "http://purl.org/dc/elements/1.1/",
    })
    E.SubElement(core, "dc:title").text = spec["model"]
    E.SubElement(core, "dc:description").text = (
        "Structural preview, not MATLAB-saved or Simulink-tested. "
        "Run START_SIMULINK_COMPARE to rebuild natively and validate."
    )
    pkg["metadata/coreProperties.xml"] = xml(core)
    rootrels = [
        ("blockDiagram", "simulink/blockdiagram.xml", "http://schemas.mathworks.com/simulink/2010/relationships/blockDiagram"),
        ("blockDiagramDefaults", "simulink/bddefaults.xml", "http://schemas.mathworks.com/simulink/2017/relationships/blockDiagramDefaults"),
        ("configSetInfo", "simulink/configSetInfo.xml", "http://schemas.mathworks.com/simulink/2014/relationships/configSetInfo"),
        ("rId1", "metadata/mwcoreProperties.xml", "http://schemas.mathworks.com/package/2012/relationships/coreProperties"),
        ("rId2", "metadata/mwcorePropertiesExtension.xml", "http://schemas.mathworks.com/package/2014/relationships/corePropertiesExtension"),
        ("rId3", "metadata/mwcorePropertiesReleaseInfo.xml", "http://schemas.mathworks.com/package/2019/relationships/corePropertiesReleaseInfo"),
        ("rId4", "metadata/coreProperties.xml", "http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties"),
    ]
    pkg["_rels/.rels"] = relations(rootrels)
    types = E.Element("Types", xmlns="http://schemas.openxmlformats.org/package/2006/content-types")
    E.SubElement(types, "Default", Extension="rels", ContentType="application/vnd.openxmlformats-package.relationships+xml")
    E.SubElement(types, "Default", Extension="xml", ContentType="application/vnd.mathworks.simulink.mdl+xml")
    for part, content in [
        ("metadata/coreProperties.xml", "application/vnd.openxmlformats-package.core-properties+xml"),
        ("metadata/mwcoreProperties.xml", "application/vnd.mathworks.package.coreProperties+xml"),
        ("metadata/mwcorePropertiesExtension.xml", "application/vnd.mathworks.package.corePropertiesExtension+xml"),
        ("metadata/mwcorePropertiesReleaseInfo.xml", "application/vnd.mathworks.package.corePropertiesReleaseInfo+xml"),
        ("simulink/configSet0.xml", "application/vnd.mathworks.simulink.configSet+xml"),
        ("simulink/configSetInfo.xml", "application/vnd.mathworks.simulink.configSetInfo+xml"),
    ]:
        E.SubElement(types, "Override", PartName="/"+part, ContentType=content)
    pkg["[Content_Types].xml"] = xml(types)
    path = ROOT/"models"/(spec["model"]+".slx")
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        for name, data in pkg.items():
            z.writestr(name, data)
    return path


def validate_graph(spec):
    total = 0
    all_ids = []
    system_names = {s["id"] for s in spec["systems"]}
    for s in spec["systems"]:
        blocks = {b["name"]: b for b in s["blocks"]}
        assert len(blocks) == len(s["blocks"])
        used_inputs = set()
        for edge in s["lines"]:
            source = blocks[edge["src"]]
            dest = blocks[edge["dst"]]
            assert 1 <= edge["srcPort"] <= source["ports"][1]
            assert 1 <= edge["dstPort"] <= dest["ports"][0]
            key = edge["dst"], edge["dstPort"]
            assert key not in used_inputs
            used_inputs.add(key)
        for b in blocks.values():
            for port in range(1, b["ports"][0]+1):
                assert (b["name"], port) in used_inputs, (s["id"], b["name"], port)
            assert not b["subsystem"] or b["subsystem"] in system_names
            all_ids.append(b["sid"])
        total += len(blocks)
    assert len(all_ids) == len(set(all_ids))
    return dict(systems=len(spec["systems"]), blocks=total, all_inputs_connected=True)


if __name__ == "__main__":
    spec = graph()
    report = validate_graph(spec)
    (ROOT/"tools/model_graph.json").write_text(json.dumps(spec, indent=2))
    path = make_slx(spec)
    report.update(draft_slx_created=path.name, matlab_compiled=False, simulink_executed=False)
    (ROOT/"validation/structural_check.json").write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2))
