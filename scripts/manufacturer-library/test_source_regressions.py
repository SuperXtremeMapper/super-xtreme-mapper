"""Selected source-derived checks; these do not establish exhaustive accuracy."""
import json
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]/'docs/manufacturer-library/2026-09-12/extracted'

def model(name):
    for path in ROOT.rglob('*.json'):
        data=json.loads(path.read_text())
        if isinstance(data,dict) and data.get('model')==name and data.get('status')=='documented-extraction': return data
    raise AssertionError(f'Missing model extraction: {name}')

class SourceRegressionTests(unittest.TestCase):
    def test_flx4_play_chart_has_base_and_shift_in_both_directions(self):
        # Official MIDI chart PDF p1, PLAY/PAUSE rows: 0B/0E, status90/91.
        bindings=[b for b in model('DDJ-FLX4')['bindings'] if b['control']=='PLAY/PAUSE']
        found={(b['direction'],b['channel'],b['number']) for b in bindings}
        expected={(d,c,n) for d in ('device-to-host','host-to-device') for c in (1,2) for n in (11,14)}
        self.assertEqual(found,expected)
    def test_flx4_tempo_is_paired_input_only(self):
        # Official MIDI chart PDF p2, TEMPO rows; MIDI-OUT is absent.
        bindings=[b for b in model('DDJ-FLX4')['bindings'] if b['control']=='TEMPO']
        self.assertTrue(bindings)
        self.assertEqual({b['direction'] for b in bindings},{'device-to-host'})
        self.assertEqual({b['channel'] for b in bindings},{1,2})
        self.assertTrue(all(b['message_type']=='compound' for b in bindings))
    def test_a9_trim_retains_channel_strip_identity(self):
        # MIDI chart pp2–4 repeats TRIM across four distinct channel strips.
        bindings=[b for b in model('DJM-A9')['bindings'] if b['control']=='TRIM']
        self.assertEqual({(b.get('source_group'),b['number']) for b in bindings},{('CH1',1),('CH2',6),('CH3',12),('CH4',80)})

    def test_lc6000_needle_scrub_ambiguity_is_quarantined(self):
        # Official MIDI specification p4 repeats CC40 for upper/lower bytes.
        data=model('LC6000 PRIME')
        for b in data['bindings']:
            if 'needle' in b['control'].lower():
                self.assertEqual(b['message_type'],'note',b)
                self.assertEqual(b['number'],70,b) # p3 touch is separate, documented.
        self.assertTrue(any(i['severity']=='conflict' and 'needle' in i['description'].lower() for i in data['issues']))
    def test_apc_mini_faders_use_human_channel_one(self):
        # Communication protocol v1.0: CC30..38 hex, channel0 on source port0.
        bindings=[b for b in model('APC mini mk2')['bindings'] if b['direction']=='device-to-host' and b['message_type']=='cc' and b['number'] in range(48,57)]
        self.assertEqual({(b['channel'],b['number']) for b in bindings},{(1,n) for n in range(48,57)})

if __name__=='__main__':unittest.main()
