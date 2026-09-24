"""Run with python tools/comfy_texture_test.py; no server or GPU required."""
import contextlib
import io
import json
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

import comfy_texture


def main():
    plate = comfy_texture.build_prompt("painted concrete", "plate")
    tiled = comfy_texture.build_prompt("painted concrete", "tileable")
    for forbidden in ("no text", "no letters", "no numbers", "no logos", "no brands",
                      "no perspective", "no directional lighting"):
        assert forbidden in plate
    assert comfy_texture.TILEABLE_SUFFIX not in plate
    assert comfy_texture.TILEABLE_SUFFIX in tiled
    graph = comfy_texture.workflow("mud", "tileable", 512, 256, 42, 4)
    assert graph["4"]["inputs"]["text"] == comfy_texture.build_prompt("mud", "tileable")
    assert graph["6"]["inputs"]["width"] == 512
    assert graph["6"]["inputs"]["height"] == 256
    assert graph["7"]["inputs"]["seed"] == 42

    with tempfile.TemporaryDirectory() as directory:
        arguments = ["comfy_texture", "mud_v1", "red mud", "--mode", "tileable",
                     "--w", "64", "--h", "32", "--seed", "7", "--out", directory]
        outputs = {"9": {"images": [{"filename": "remote.png", "type": "output"}]}}
        with patch.object(sys, "argv", arguments), \
                patch.object(comfy_texture.comfy_api, "run", return_value=outputs) as run, \
                patch.object(comfy_texture.comfy_api, "get_bytes", return_value=b"PNG"), \
                contextlib.redirect_stdout(io.StringIO()):
            assert comfy_texture.main() == 0
        submitted = run.call_args.args[0]
        assert submitted["4"]["inputs"]["text"] == comfy_texture.build_prompt("red mud", "tileable")
        assert run.call_args.kwargs["budget_s"] == 300
        assert (Path(directory) / "mud_v1.png").read_bytes() == b"PNG"
        metadata = json.loads((Path(directory) / "mud_v1.json").read_text(encoding="utf-8"))
        assert metadata["mode"] == "tileable"
        assert metadata["prompt_base"] == "red mud"
        assert metadata["positive_prompt"] == submitted["4"]["inputs"]["text"]
        assert metadata["fixed_negative_wording"] == comfy_texture.FIXED_NEGATIVE
        assert metadata["width"] == 64 and metadata["height"] == 32
        assert metadata["seed"] == 7
    print("PASS: fixed wording, modes, workflow and mocked provenance")


if __name__ == "__main__":
    main()
