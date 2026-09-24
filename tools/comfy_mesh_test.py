"""Run with python tools/comfy_mesh_test.py; no server or GPU required."""
import contextlib
import io
import json
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

import comfy_mesh


def main():
    default = comfy_mesh.workflow("reference.png", "test", 56, 20000, 1024)
    assert default["241"]["inputs"]["resolution"] == 768
    for upsample in (False, True):
        graph = comfy_mesh.workflow("reference.png", "test", 56, 20000, 1024,
                                    upsample=upsample, remesh_resolution=512)
        assert graph["241"]["inputs"]["resolution"] == 512
        assert graph["241"]["inputs"]["mesh"] == ["202", 0]
        assert graph["202"]["inputs"]["mesh"] == ["92", 0]
        assert ("94" in graph) == upsample
        assert ("23" in graph) == upsample
        for node in graph.values():
            for value in node["inputs"].values():
                if isinstance(value, list):
                    assert len(value) == 2 and value[0] in graph, value
                    assert isinstance(value[1], int) and value[1] >= 0, value
    for invalid in ("31", "2049", "bad"):
        with patch.object(sys, "argv", ["comfy_mesh", "missing.png", "test",
                                      "--remesh-resolution", invalid]), \
                patch.object(comfy_mesh.comfy_api, "upload_image") as upload, \
                contextlib.redirect_stderr(io.StringIO()):
            try:
                comfy_mesh.main()
            except SystemExit as error:
                assert error.code == 2, error
            else:
                raise AssertionError("Invalid resolution accepted")
            upload.assert_not_called()
    with tempfile.TemporaryDirectory() as directory:
        image = Path(directory) / "reference.png"
        image.write_bytes(b"test input")
        arguments = ["comfy_mesh", str(image), "test", "--no-upsample",
                     "--remesh-resolution", "512", "--out", directory]
        outputs = {"322": {"files": [{"filename": "test.glb"}]}}
        with patch.object(sys, "argv", arguments), \
                patch.object(comfy_mesh.comfy_api, "upload_image", return_value=image.name), \
                patch.object(comfy_mesh.comfy_api, "run", return_value=outputs) as run, \
                patch.object(comfy_mesh.comfy_api, "get_bytes", return_value=b"glTF"):
            assert comfy_mesh.main() == 0
        assert run.call_args.args[0]["241"]["inputs"]["resolution"] == 512
        assert run.call_args.kwargs["budget_s"] == 1800
        metadata = json.loads((Path(directory) / "test.json").read_text(encoding="utf-8"))
        assert metadata["remesh_resolution"] == 512
        assert metadata["upsample"] is False
    print("PASS: default, remesh override, graph links, CLI validation and metadata")


if __name__ == "__main__":
    main()
