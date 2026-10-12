"""Persisted Meshy rig pilot for the new ImageGen-reference guard model.

The script never replaces runtime assets.  It stores the submitted task id so
an interrupted call is always resumed by polling rather than duplicated.
"""
from pathlib import Path
import json
import sys

import meshy3d


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/art/Artwork/3d/cast_redesign_v1/guard"
STATE = OUT / "rebuild_pipeline.json"


def load() -> dict:
	return json.loads(STATE.read_text(encoding="utf-8")) if STATE.exists() else {}


def save(state: dict) -> None:
	STATE.write_text(json.dumps(state, indent=2), encoding="utf-8")


def create() -> None:
	state = load()
	if state.get("rig_task_id"):
		print(json.dumps({"task_id": state["rig_task_id"], "action": "reuse"}))
		return
	if state.get("rig_submission_started"):
		raise RuntimeError("Unknown rig submission outcome; inspect state before retry")
	model_task = json.loads((OUT / "meshy_task.json").read_text(encoding="utf-8"))["task_id"]
	state.update({
		"model_task_id": model_task,
		"rig_submission_started": True,
		"runtime_approved": False,
		"height_meters": 1.80,
	})
	save(state)
	response = meshy3d.call("POST", "/v1/rigging", {
		"input_task_id": model_task,
		"height_meters": state["height_meters"],
	})
	state["rig_task_id"] = response["result"]
	state["rig_submission_outcome"] = "task_id_received"
	save(state)
	print(json.dumps({"task_id": state["rig_task_id"], "runtime_approved": False}))


def status(download: bool) -> None:
	state = load()
	if not state.get("rig_task_id"):
		raise RuntimeError("No rig task has been created")
	task = meshy3d.call("GET", "/v1/rigging/" + state["rig_task_id"])
	state["last_response"] = task
	save(state)
	print(json.dumps({key: task.get(key) for key in ("id", "status", "progress", "consumed_credits", "task_error")}))
	if not download or task.get("status") != "SUCCEEDED":
		return
	for key, url in task.get("result", {}).items():
		if isinstance(url, str) and url.startswith("http") and key.endswith("_url"):
			ext = ".fbx" if "fbx" in key else ".glb"
			meshy3d.fetch(url, str(OUT / "rig" / (key.removesuffix("_url") + ext)))


def create_motions() -> None:
	state = load()
	if not state.get("rig_task_id"):
		raise RuntimeError("Rig must finish before motions can be submitted")
	if state.get("motion_task_id"):
		print(json.dumps({"task_id": state["motion_task_id"], "action": "reuse"}))
		return
	if state.get("motion_submission_started"):
		raise RuntimeError("Unknown motion submission outcome; inspect state before retry")
	actions = [30, 14, 524, 234, 233]
	state.update({"motion_submission_started": True, "motion_action_ids": actions})
	save(state)
	response = meshy3d.call("POST", "/v1/animations", {
		"rig_task_id": state["rig_task_id"],
		"action_ids": actions,
		"post_process": {"operation_type": "change_fps", "fps": 60},
	})
	state["motion_task_id"] = response["result"]
	state["motion_submission_outcome"] = "task_id_received"
	save(state)
	print(json.dumps({"task_id": state["motion_task_id"], "runtime_approved": False}))


def motion_status(download: bool) -> None:
	state = load()
	if not state.get("motion_task_id"):
		raise RuntimeError("No motion task has been created")
	task = meshy3d.call("GET", "/v1/animations/" + state["motion_task_id"])
	state["last_motion_response"] = task
	save(state)
	print(json.dumps({key: task.get(key) for key in ("id", "status", "progress", "consumed_credits", "task_error")}))
	if not download or task.get("status") != "SUCCEEDED":
		return
	for key in ("animation_glb_url", "animation_fbx_url"):
		url = task.get("result", {}).get(key)
		if url:
			ext = ".fbx" if key.endswith("fbx_url") else ".glb"
			meshy3d.fetch(url, str(OUT / "motions" / ("library_batch" + ext)))


if __name__ == "__main__":
	command = sys.argv[1]
	if command == "create":
		create()
	elif command == "status":
		status(False)
	elif command == "download":
		status(True)
	elif command == "motions-create":
		create_motions()
	elif command == "motions-status":
		motion_status(False)
	elif command == "motions-download":
		motion_status(True)
	else:
		raise SystemExit("use create, status, download, motions-create, motions-status or motions-download")
