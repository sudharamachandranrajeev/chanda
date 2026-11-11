"""Builds assets/search/attributes.json: the words people use for what they
want in a product ("easy slip in", "all terrains") and the words shops put in
titles for the same thing ("slip-on", "trail").

Two sources:
  1. tool/attribute_hand.json, written by hand: the main attributes, with the
     ways people ask for them and the ways shops write them.
  2. The Shopify Standard Product Taxonomy (MIT, (c) Shopify), at a pinned
     revision: the values of a chosen set of product attributes (closure
     types, shoe and clothing features, fits, styles), each as its own
     attribute, asked for and written the same way.

usage: python3 -I tool/attribute_lexicon.py <taxonomy attributes.json>
  The file is dist/en/attributes.json from
  https://github.com/Shopify/product-taxonomy at TAXONOMY_REV (download it
  first; this script does not fetch anything).
"""
import json
import os
import re
import sys

TAXONOMY_REV = '4f8accb9135b313fb17a935f2f74694cdb23a607'
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'assets', 'search', 'attributes.json')

# Taxonomy attributes whose values are things shoppers ask for.
HANDLES = [
    'activewear-clothing-features', 'clothing-features', 'baby-toddler-clothing-features', 'closure-type',
    'features', 'bag-case-features', 'chair-sofa-features', 'drinkware-insulation', 'flask-insulation-type',
    'footwear-cut', 'footwear-support-type', 'fit', 'fit-volume-classification', 'heel-height-type',
    'dress-style', 'eyewear-frame-design', 'headphone-style', 'glove-insulation', 'glove-finger-coverage',
    'jacket-breast-style', 'neckline', 'sleeve-length-type', 'sleeve-style', 'boot-style', 'flat-shoe-style',
    'sandal-style', 'sneaker-style', 'shoe-features', 'shoe-fit', 'toe-style', 'toe-coverage',
    'pants-length-type', 'top-length-type', 'skirt-dress-length-type', 'outerwear-length-type',
    'rise-height-class', 'shoe-collar-height', 'bra-features', 'battery-features', 'allergy-friendly-features',
]

# One word alone is kept only when it clearly describes a product, not when
# it is a common word ("light", "standard") that would take over a search.
SINGLE_OK = re.compile(r'(proof|able|ible|less|ed|ive|ant|ent|wicking|lined|weight|free)$')
SINGLE_NO = {'other', 'none', 'standard', 'regular', 'classic', 'universal', 'medium', 'high', 'low', 'mid',
             'light', 'flat', 'round', 'wide', 'slim', 'straight', 'back', 'front', 'boot', 'shirt', 'jacket',
             'pencil', 'flared', 'tapered', 'fixed', 'combined', 'sleeved', 'printed', 'detailed',
             'closed', 'open', 'integrated', 'concealed', 'traditional', 'unspecified', 'customized',
             'removable', 'elastic', 'drawstring', 'hooded', 'collared'}


def key(phrase):
    return ' '.join(re.findall(r'[a-z0-9]+', phrase.lower()))


def slug(label):
    return re.sub(r'[^a-z0-9]+', '-', label.lower()).strip('-')


def main(taxonomy_path):
    hand = json.load(open(os.path.join(HERE, 'attribute_hand.json')))
    out = {}
    for a in hand['attributes']:
        a = dict(a)
        a.setdefault('id', slug(a['label']))
        out[a['id']] = a
    by_key = {key(p): a['id'] for a in out.values() for p in a['say']}

    tax = json.load(open(taxonomy_path))
    wanted = set(HANDLES)
    added = 0
    for attr in tax['attributes']:
        if attr['handle'] not in wanted:
            continue
        for v in attr.get('values', []):
            name = re.sub(r'\s*\(.*?\)', '', v['name']).strip()
            k = key(name)
            if not k or re.search(r'\d', k) or len(k.split()) > 3:
                continue
            words = k.split()
            if len(words) == 1 and (k in SINGLE_NO or not SINGLE_OK.search(k)):
                continue
            if k in by_key:
                a = out[by_key[k]]
                if name.lower() not in [t.lower() for t in a['title']]:
                    a['title'].append(name.lower())
                continue
            i = slug(name)
            if i in out:
                continue
            out[i] = {'id': i, 'label': name[0].upper() + name[1:], 'say': [name.lower()], 'title': [name.lower()]}
            by_key[k] = i
            added += 1

    doc = {
        'about': 'What people ask for and how shops write it. Built by tool/attribute_lexicon.py from '
                 'tool/attribute_hand.json and the Shopify Standard Product Taxonomy (MIT, (c) Shopify) at '
                 'revision ' + TAXONOMY_REV + '. See THIRD_PARTY_NOTICES.md.',
        'attributes': sorted(out.values(), key=lambda a: a['id']),
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w') as f:
        json.dump(doc, f, ensure_ascii=False, separators=(',', ':'))
        f.write('\n')
    print(f'{len(out)} attributes ({added} from the taxonomy), {os.path.getsize(OUT)} bytes')


if __name__ == '__main__':
    main(sys.argv[1])
