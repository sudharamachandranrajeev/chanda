"""Builds assets/pictures/labels.json and labels.bin: the picture model's
vectors for a fixed list of labels (what a thing is, its colour, its
pattern), so the app can name what is in a photo without shipping the
model's text half.

Run with the fp32 text model and tokenizer of Marqo/marqo-fashionSigLIP at
the revision below, downloaded into one folder:

    python3 -I tool/picture_labels.py <folder> [photos...]

Needs numpy, onnxruntime and tokenizers. Photos, if given, are labelled
with the int8 vision model in the same folder as a check.
"""

import json
import sys
from pathlib import Path

import numpy as np
import onnxruntime as ort
from tokenizers import Tokenizer

REVISION = "c56244cc94f92419e8369fa71efdaf403b124ce8"

# What a thing is. The name is what Chanda searches shops for.
CATEGORIES = [
    # clothes
    "t-shirt", "shirt", "blouse", "polo shirt", "jumper", "cardigan", "hoodie", "sweatshirt",
    "jacket", "coat", "blazer", "waistcoat", "dress", "skirt", "jeans", "trousers", "shorts",
    "leggings", "joggers", "suit", "jumpsuit", "pyjamas", "swimsuit", "bikini", "underwear",
    "bra", "socks", "tights",
    # shoes and accessories
    "trainers", "boots", "sandals", "heels", "flat shoes", "loafers", "slippers",
    "handbag", "backpack", "tote bag", "wallet", "belt", "hat", "cap", "scarf", "gloves", "tie",
    "glasses", "sunglasses", "watch", "necklace", "earrings", "ring", "bracelet", "hair clip",
    "umbrella", "suitcase",
    # tech
    "phone", "phone case", "laptop", "tablet", "headphones", "earbuds", "speaker", "smartwatch",
    "camera", "television", "computer monitor", "keyboard", "computer mouse", "charger", "cable",
    "power bank", "game console", "game controller", "printer",
    # home
    "lamp", "chair", "sofa", "table", "desk", "bed", "pillow", "duvet", "rug", "curtains",
    "mirror", "clock", "vase", "plant pot", "candle", "picture frame", "shelf", "storage box",
    "mug", "plate", "bowl", "glassware", "cutlery", "saucepan", "frying pan", "kettle",
    "toaster", "coffee machine", "blender", "vacuum cleaner", "towel", "bedding",
    # other
    "toy", "doll", "building blocks", "book", "notebook", "pen", "bicycle", "helmet",
    "tent", "yoga mat", "dumbbells", "perfume", "lipstick", "skincare bottle", "makeup brush",
    "hair dryer", "shaver", "jewellery box", "dog bed", "pet toy", "garden tool", "drill",
    "screwdriver", "light bulb",
]

COLOURS = [
    "black", "white", "grey", "silver", "gold", "red", "burgundy", "pink", "orange", "yellow",
    "beige", "brown", "green", "olive", "teal", "blue", "navy", "purple", "multicolour",
]

PATTERNS = ["plain", "striped", "checked", "floral", "polka dot", "animal print", "camouflage", "graphic print"]


def prompts():
    for c in CATEGORIES:
        yield "category", c, f"a photo of {'an' if c[0] in 'aeiou' else 'a'} {c}"
    for c in COLOURS:
        yield "colour", c, f"a photo of a {c} product"
    for p in PATTERNS:
        yield "pattern", p, f"a photo of a {p} product"


def main(folder, photos):
    folder = Path(folder)
    tok = Tokenizer.from_file(str(folder / "tokenizer.json"))
    text = ort.InferenceSession(str(folder / "text_model.onnx"), providers=["CPUExecutionProvider"])
    rows = list(prompts())
    ids = []
    for _, _, p in rows:
        t = tok.encode(p.lower()).ids[:64]
        ids.append(t + [1] * (64 - len(t)))  # padded with </s>, as open_clip does
    vec = text.run(None, {"input_ids": np.array(ids, dtype=np.int64)})[0]
    vec /= np.linalg.norm(vec, axis=1, keepdims=True)
    out = Path(__file__).resolve().parent.parent / "assets" / "pictures"
    out.mkdir(parents=True, exist_ok=True)
    vec.astype("<f2").tofile(out / "labels.bin")
    (out / "labels.json").write_text(
        json.dumps(
            {
                "model": "Marqo/marqo-fashionSigLIP",
                "revision": REVISION,
                "dims": int(vec.shape[1]),
                "format": "float16 little-endian, one row per label, unit length",
                "labels": [{"kind": k, "name": n} for k, n, _ in rows],
            },
            indent=1,
        )
        + "\n"
    )
    print(len(rows), "labels written to", out)
    if photos:
        from PIL import Image

        vision = ort.InferenceSession(str(folder / "vision_model_int8.onnx"), providers=["CPUExecutionProvider"])
        for p in photos:
            im = Image.open(p).convert("RGB").resize((224, 224), Image.BICUBIC)
            a = ((np.asarray(im, dtype=np.float32) / 255 - 0.5) / 0.5).transpose(2, 0, 1)[None]
            e = vision.run(None, {"pixel_values": a})[0][0]
            e /= np.linalg.norm(e)
            s = vec @ e
            best = {}
            for (k, n, _), v in zip(rows, s):
                best.setdefault(k, []).append((v, n))
            print(Path(p).name, {k: [n for _, n in sorted(v, reverse=True)[:2]] for k, v in best.items()})


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
