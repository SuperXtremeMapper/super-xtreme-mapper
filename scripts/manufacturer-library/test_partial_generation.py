import json
from pathlib import Path
import tempfile
import unittest
import generate_profiles as g

class PartialGenerationTests(unittest.TestCase):
    def dataset(self, directory):
        value=dict(schema_version=1,manufacturer='Example',model='Controller',status='partial-extraction',coverage_state='documentation-only',hardware_tested=False,scope='MIDI mode only.',setup_notes=['Choose MIDI mode in hardware settings.'],missing_information=['No numeric address table.'],sources=[dict(id='s',url='https://example.com/manual',sha256='a'*64,local_file='manual.pdf')],bindings=[],issues=[dict(id='gap',severity='scope',description='No numeric address table.',excluded_bindings=['Control addresses'],evidence=[dict(source_id='s',locator='Page 5')])],raw_evidence=[])
        path=Path(directory)/'example.json';path.write_text(json.dumps(value));return path
    def test_documentation_only_generates_no_fake_control(self):
        with tempfile.TemporaryDirectory() as directory:
            profile=g.build_profile(self.dataset(directory))
            self.assertEqual(profile['controls'],[])
            self.assertEqual(profile['coverageState'],'documentationOnly')
            self.assertTrue(profile['modes'])
            self.assertTrue(profile['configurationEvidence'])
            self.assertTrue(any('numeric address' in n for n in profile['coverageNotes']))
    def test_partial_profile_carries_explicit_label_and_setup(self):
        with tempfile.TemporaryDirectory() as directory:
            path=self.dataset(directory);data=json.loads(path.read_text());data['coverage_state']='partial'
            data['bindings']=[dict(id='b1',control='Fader',direction='device-to-host',message_type='cc',channel=1,number=7,encoding='absolute7Bit',values={'min':0,'max':127},mode='documented',evidence=[dict(source_id='s',locator='Page 6')],app_support='requires-adapter',notes=[])]
            path.write_text(json.dumps(data));profile=g.build_profile(path)
            self.assertEqual(profile['coverageState'],'partial')
            self.assertTrue(any('Choose MIDI mode' in n for n in profile['coverageNotes']))

if __name__=='__main__':unittest.main()
