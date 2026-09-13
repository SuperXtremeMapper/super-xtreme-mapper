"""Reproducibility, completeness and safety regressions for the runtime catalogue."""
import hashlib
import json
import unittest
import generate_profiles as generator


class GeneratedProfilesTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.resources = generator.generated_resources()
        cls.profiles = {json.loads(payload)['id']: json.loads(payload)
                        for name, payload in cls.resources.items() if name != 'controller-profile-catalogue.json'}

    def test_exact_47_pinned_resources_are_reproducible_and_bounded(self):
        manifest = json.loads(self.resources['controller-profile-catalogue.json'])['resources']
        self.assertEqual(len(manifest), 47)
        self.assertEqual(len(set(manifest)), 47)
        self.assertEqual(set(manifest), {p.stem for p in generator.OUTPUT.glob('*.json') if p.stem != 'controller-profile-catalogue'})
        for name, payload in self.resources.items():
            self.assertEqual((generator.OUTPUT / name).read_bytes(), payload, name)
            self.assertLessEqual(len(payload), generator.MAX_BYTES)
        self.assertLess(sum(len(p) for p in self.resources.values()), 64_000_000)

    def test_all_established_profiles_byte_exact(self):
        hashes = json.loads((generator.ROOT / 'scripts/manufacturer-library/established-profile-hashes.json').read_text())
        self.assertEqual(len(hashes), 26)
        for name, expected in hashes.items():
            self.assertEqual(hashlib.sha256((generator.OUTPUT / (name + '.json')).read_bytes()).hexdigest(), expected, name)

    def test_partial_coverage_and_configurable_px5(self):
        self.assertEqual(sum(p.get('coverageState') == 'partial' for p in self.profiles.values()), 8)
        self.assertEqual(sum(p.get('coverageState') == 'documentationOnly' for p in self.profiles.values()), 13)
        for profile in self.profiles.values():
            self.assertEqual(not profile['controls'], profile.get('coverageState') == 'documentationOnly')
        px5 = self.profiles['allen-heath.xone-px5']
        self.assertEqual(px5['defaultChannel'], 16)
        self.assertTrue(all(b['channel'] is None for c in px5['controls'] for b in c['bindings']))

    def test_legacy_resources_byte_exact(self):
        hashes = {'xone-k1': '8bb308c10451e4b0602245e4c2c1b4dc18c0f81ddefdabc73c8b5120ec368b79',
                  'xone-k2': '113c5191e4a8d016fd99978129885d6537d90e4476666677d5158cf5515ed852',
                  'xone-k3': 'b070a89d97c8ea6d99e8b55c62cf149f0fb7af6881ea7391f168e047d951a6d8'}
        for name, expected in hashes.items():
            self.assertEqual(hashlib.sha256((generator.OUTPUT / (name + '-1.0.0.json')).read_bytes()).hexdigest(), expected)

    def test_every_extracted_record_and_issue_preserved_exactly(self):
        for path in list(generator.EXTRACTED.glob('*/*.json')) + list(generator.PARTIAL.glob('*/*.json')):
            if path.stem in generator.LEGACY:
                continue
            source = json.loads(path.read_text())
            if not isinstance(source, dict) or source.get('status') not in ('documented-extraction', 'partial-extraction'):
                continue
            profile = self.profiles[generator.slug(source['manufacturer']) + '.' + path.stem]
            retained = [json.loads(b['semantics']) for c in profile['controls'] for b in c['bindings']]
            self.assertEqual(retained, source['bindings'], path.stem)
            for issue, limitation in zip(source['issues'], profile['limitations']):
                self.assertIn(issue['description'], limitation['message'])
                self.assertEqual(limitation['message'], generator.display_issue(issue))
            self.assertEqual([(s['id'], s['url'], s['sha256']) for s in profile['sources']],
                             [(s['id'], s['url'], s['sha256']) for s in source['sources']])

    def test_all_evidence_modes_ports_and_components_have_valid_references(self):
        for profile in self.profiles.values():
            sources = {x['id'] for x in profile['sources']}
            evidence = {x['id']: x for x in profile['evidence']}
            modes = {x['id'] for x in profile['modes']}
            ports = {x['id'] for x in profile['ports']}
            self.assertEqual(len({c['id'] for c in profile['controls']}), len(profile['controls']))
            for item in evidence.values():
                self.assertIn(item['sourceID'], sources)
                self.assertTrue(item['locator'])
            for item in profile['controls'] + profile['limitations'] + profile['modes'] + profile['unitMaps']:
                self.assertTrue(item['evidence'])
                self.assertTrue(set(item['evidence']) <= evidence.keys())
            for control in profile['controls']:
                for binding in control['bindings']:
                    raw = json.loads(binding['semantics'])
                    self.assertEqual([(evidence[e]['sourceID'], evidence[e]['locator']) for e in binding['evidence']],
                                     [(e['source_id'], e['locator']) for e in raw['evidence']])
                    self.assertIn(binding['modeID'], modes)
                    if binding['portID']:
                        self.assertIn(binding['portID'], ports)
                    if binding['support'] == 'available':
                        self.assertIn(binding['kind'], ('note', 'controlChange'))
                        self.assertIsInstance(binding['number'], int)
                        self.assertTrue(0 <= binding['number'] <= 127)
                        self.assertFalse(generator.is_pair(raw))
                    else:
                        self.assertIsNone(binding['number'])
                    if binding['kind'] == 'compound':
                        self.assertGreaterEqual(len(binding.get('components', [])), 2)
                    self.assertLessEqual(len(binding['semantics'].encode()), 16_384)

    def test_representative_xone96_configurable_fader_and_discrete_selector(self):
        profile = self.profiles['allen-heath.xone-96']
        self.assertEqual(profile['defaultChannel'], 16)
        first = profile['controls'][0]['bindings'][0]
        self.assertEqual((first['kind'], first['number'], first['channel']), ('controlChange', 0, None))
        self.assertFalse(profile['ports'])
        selectors = [b for c in profile['controls'] for b in c['bindings'] if 'rotary switch position USB 1' == b['context']]
        self.assertTrue(selectors)
        self.assertTrue(all(b['kind'] == 'note' for b in selectors))

    def test_representative_flx4_fixed_channel_and_paired_tempo(self):
        profile = self.profiles['pioneer-dj.ddj-flx4']
        first = profile['controls'][0]['bindings'][0]
        self.assertEqual((first['kind'], first['number'], first['channel']), ('note', 11, 1))
        tempo = next(c['bindings'][0] for c in profile['controls'] if c['id'] == 'b00071')
        self.assertEqual(tempo['support'], 'documentedOnly')
        self.assertEqual(tempo['kind'], 'compound')
        self.assertEqual([c['number'] for c in tempo['components']], [0, 32])
        self.assertIsNone(tempo['number'])
        self.assertIn('not a claimed manufacturer default', ' '.join(profile['coverageNotes']))

    def test_representative_launchpad_programmer_input_and_palette(self):
        profile = self.profiles['novation.launchpad-x']
        first = profile['controls'][0]['bindings'][0]
        self.assertEqual((first['number'], first['channel'], first['modeID']), (11, None, 'programmer'))
        self.assertTrue(any(b['encoding'] == 'palette' and b['direction'] == 'receive' for c in profile['controls'] for b in c['bindings']))
        self.assertFalse(profile['ports'])

    def test_display_names_and_coverage_hide_raw_extraction_syntax(self):
        for profile in self.profiles.values():
            for control in profile['controls']:
                self.assertNotIn('[' + control['id'] + ']', control['name'])
                self.assertNotIn(' | ', control['name'])
                self.assertNotIn(' — - — ', control['name'])
                self.assertNotIn(' — send', control['name'])
                self.assertNotIn(' — receive', control['name'])
            for limitation in profile['limitations']:
                self.assertFalse(limitation['message'].lstrip().startswith('{'))
                self.assertNotIn('"excluded_bindings":', limitation['message'])
                self.assertNotIn('"source_id":', limitation['message'])
        play = self.profiles['pioneer-dj.ddj-flx4']['controls'][0]
        self.assertEqual(play['name'], 'Deck · PLAY/PAUSE — Deck 1 · Press — Channel 1 — Input')

    def test_modes_and_ports_are_explicit_and_conservative(self):
        profile = self.profiles['faderfox.faderfox-uc4']
        self.assertEqual({m['id'] for m in profile['modes']}, {'setup-' + str(i) for i in range(1, 19)})
        apc = self.profiles['akai-professional.akai-apc-mini-mk2']
        self.assertEqual({p['id'] for p in apc['ports']}, {'port-0', 'port-1'})
        for key in ['akai-professional.akai-apc-mini-mk2', 'akai-professional.akai-apc40-mkii']:
            self.assertEqual({b['modeID'] for c in self.profiles[key]['controls'] for b in c['bindings']}, {'documented'})
        for mode in ['rotary switch position USB 1', 'MIDI USB interface', 'DAW USB interface']:
            self.assertIsNone(generator.explicit_port({'values': {}, 'mode': mode}))
        self.assertEqual(generator.explicit_port({'values': {}, 'mode': 'Note Mode; port 1; protocol chart only'}), '1')


if __name__ == '__main__':
    unittest.main()
