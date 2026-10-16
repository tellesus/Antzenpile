"""Run gameplay checks in an actual non-debug Windows export, isolated from player data.
The temporary test package is separate from the distributable. Runtime files are
copied unchanged; test-only assert calls become evaluated fixture requirements.
"""
import argparse, os, re, shutil, subprocess, tempfile
from pathlib import Path
from build_windows_beta import checked, completed_import_fault
ROOT=Path(__file__).resolve().parents[2]
SUITES=['conflict_recruitment','combat_clarity','ambusher_defense','armed_search','rival_continuity','rival_counterplay','predator','journey_investigation','rain','refuge_crisis','queen_continuity','reproduction','roaming_predator']

def audit_assertions():
    # Runtime assertions may inspect state; all mutation must execute in release.
    pure={'has','is_empty','queen_id','invariant_holds'}
    for path in (ROOT/'src').rglob('*.gd'):
        source=path.read_text(encoding='utf-8')
        for start in re.finditer(r'\bassert\(',source):
            end=start.end();depth=1;quoted=False
            while depth:
                char=source[end]
                if char=='"' and source[end-1]!='\\':quoted=not quoted
                if not quoted:
                    if char=='(':depth+=1
                    if char==')':depth-=1
                end+=1
            expression=source[start.end():end-1]
            calls=set(re.findall(r'\b([A-Za-z_][A-Za-z_0-9]*)\s*\(',expression))
            if calls-pure:raise RuntimeError(f'Unreviewed assertion call in {path}: {expression}')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',type=Path,required=True)
    parser.add_argument('--templates',type=Path,required=True)
    parser.add_argument('--baseline-ref',help='Reproduce the defect using a historical runtime ref (e.g. e8742f4)')
    args=parser.parse_args()
    audit_assertions()
    work=Path(tempfile.mkdtemp(prefix='release-gameplay-',dir=ROOT/'.godot'))
    source=work/'source';source.mkdir()
    for name in ['src','data','assets','scenes','tests']:
        shutil.copytree(ROOT/name,source/name,ignore=shutil.ignore_patterns('__pycache__'))
    if args.baseline_ref:
        for p in (source/'src').rglob('*.gd'):
            rel=p.relative_to(source).as_posix()
            result=subprocess.run(['git','show',args.baseline_ref+':'+rel],cwd=ROOT,capture_output=True)
            if result.returncode==0:p.write_bytes(result.stdout)
    for p in (source/'tests').rglob('*.gd'):
        s=p.read_text(encoding='utf-8').replace('assert(', 'preload("res://fixture_requirement.gd").require(')
        p.write_text(s,encoding='utf-8')
    (source/'fixture_requirement.gd').write_text('''extends RefCounted
static func require(condition: bool, message: String = "Fixture requirement") -> void:
	if not condition:
		push_error(message)
		OS.crash(message)
''',encoding='utf-8')
    baseline='''
	var game: SimulationController=preload("res://tests/test_gathering_orders.gd").new().ready()
	check(game.create_trail("home","known:carb_sheltered",5),"Real paid gathering fixture")
	game.journey_response.recruitment.request("route_1",3,"defend",false)
	check(game.run.colony.piles.home.workers.count("response:route_1")>=0,"Recruitment creates its real ledger pool in release")
'''
    suite_rows='\n'.join('\tcheck(preload("res://tests/test_'+name+'.gd").new().run(self),"Suite '+name+'")' for name in SUITES)
    runner='''extends Node
var checks: int=0
var failures: int=0
func _ready() -> void: _run.call_deferred()
func get_root() -> Window: return get_tree().root
func check(condition: bool, description: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		printerr("FAIL: "+description)
func _run() -> void:
	check(not OS.is_debug_build(),"Actual non-debug release template")
'''+(baseline if args.baseline_ref else suite_rows)+'\n\tprint("RELEASE GAMEPLAY: %d checks, %d failures" % [checks,failures])\n\tget_tree().quit(1 if failures else 0)\n'
    (source/'release_checks.gd').write_text(runner,encoding='utf-8')
    (source/'release_checks.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://release_checks.gd" id="1"]\n[node name="ReleaseChecks" type="Node"]\nscript=ExtResource("1")\n')
    project=(ROOT/'project.godot').read_text(encoding='utf-8')
    project=re.sub(r'run/main_scene=.*', 'run/main_scene="res://release_checks.tscn"',project)
    (source/'project.godot').write_text(project,encoding='utf-8')
    preset=(ROOT/'export_presets.cfg').read_text(encoding='utf-8').replace('tests/*,','').replace('src/debug/*,','')
    preset=preset.replace('custom_template/release=""','custom_template/release="'+(args.templates/'windows_release_x86_64.exe').resolve().as_posix()+'"')
    (source/'export_presets.cfg').write_text(preset,encoding='utf-8')
    (work/'temp').mkdir()
    env=dict(os.environ,APPDATA=str(work/'user'),TEMP=str(work/'temp'),TMP=str(work/'temp'))
    common=[str(args.godot.resolve()),'--headless','--path',str(source)]
    try:checked([*common,'--editor','--import'],env=env,log=work/'import.log')
    except RuntimeError as error:
        if not completed_import_fault(error,(work/'import.log').read_text(encoding='utf-8')):raise
        checked([*common,'--editor','--import'],env=env,log=work/'import-retry.log')
    exe=work/'GameplayChecks.exe'
    checked([*common,'--export-release','Windows Systems Beta',str(exe)],env=env,log=work/'export.log')
    result=subprocess.run([str(exe),'--headless','--audio-driver','Dummy','--log-file',str(work/'checks.log')],cwd=work,env=env,capture_output=True,timeout=180)
    log=(work/'checks.log').read_text(encoding='utf-8')
    print(log);print('Evidence:',work)
    if args.baseline_ref:
        if 'FAIL: Recruitment creates its real ledger pool in release' not in log:raise RuntimeError('Expected baseline defect was not reproduced')
    elif result.returncode or 'ERROR:' in log or '0 failures' not in log:raise RuntimeError('Actual release gameplay checks failed')
if __name__=='__main__':main()
