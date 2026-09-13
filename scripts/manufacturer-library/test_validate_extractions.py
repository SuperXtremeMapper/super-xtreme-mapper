import copy
import hashlib
import tempfile
import unittest
from pathlib import Path
from validate_extractions import validate_model, validate_catalogue_coverage

class ExtractionValidationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root/'extracted').mkdir()
        (self.root/'source.txt').write_text('manufacturer source')
        (self.root/'extracted/raw.txt').write_text('PDF PAGE 1\nCC 7 volume')
        self.data = dict(schema_version=1, manufacturer='Brand', model='Device', status='documented-extraction', hardware_tested=False,
            sources=[dict(id='manual',local_file='source.txt',url='https://example.com/manual',sha256=hashlib.sha256(b'manufacturer source').hexdigest())],
            scope='Factory MIDI mode', bindings=[dict(id='fader',control='Volume',direction='device-to-host',message_type='cc',channel=1,number=7,encoding='absolute7Bit',values={'min':0,'max':127},mode='factory',evidence=[dict(source_id='manual',locator='PDF page 1')],app_support='requires-adapter',notes=[])],
            issues=[],raw_evidence=[dict(source_id='manual',file='raw.txt',extraction_method='text')])
    def check_bad(self, mutate, fragment):
        data=copy.deepcopy(self.data); mutate(data)
        self.assertTrue(any(fragment in e for e in validate_model(data,self.root)),fragment)
    def partial_document(self):
        data=copy.deepcopy(self.data)
        data.update(status='partial-extraction',coverage_state='documentation-only',bindings=[],setup_notes=['Confirm MIDI mode.'],missing_information=['Wire addresses'],issues=[dict(id='missing-map',severity='scope',description='No wire address table.',evidence=[dict(source_id='manual',locator='Page 1')],excluded_bindings=['All wire addresses'])])
        return data
    def test_explicit_documentation_only_empty_extraction_is_valid(self):
        self.assertEqual(validate_model(self.partial_document(),self.root),[])
    def test_partial_requires_nonempty_numeric_evidence(self):
        data=self.partial_document();data['coverage_state']='partial'
        self.assertTrue(validate_model(data,self.root))
    def test_documentation_only_cannot_hide_populated_bindings(self):
        data=self.partial_document();data['bindings']=self.data['bindings']
        self.assertTrue(validate_model(data,self.root))
    def test_partial_requires_missing_information(self):
        data=self.partial_document();data['missing_information']=[]
        self.assertTrue(validate_model(data,self.root))
    def test_valid_documented_binding(self):
        self.assertEqual(validate_model(self.data,self.root),[])
    def test_rejects_zero_based_channel(self):
        self.check_bad(lambda d:d['bindings'][0].update(channel=0),'channel')
    def test_rejects_out_of_range_data_byte(self):
        self.check_bad(lambda d:d['bindings'][0].update(number=128),'number')
    def test_rejects_missing_binding_evidence(self):
        self.check_bad(lambda d:d['bindings'][0].update(evidence=[]),'evidence')
    def test_rejects_unknown_source_reference(self):
        self.check_bad(lambda d:d['bindings'][0]['evidence'][0].update(source_id='absent'),'source')
    def test_rejects_changed_original(self):
        (self.root/'source.txt').write_text('changed')
        self.assertTrue(any('hash' in e for e in validate_model(self.data,self.root)))
    def test_rejects_missing_raw_evidence(self):
        self.check_bad(lambda d:d['raw_evidence'][0].update(file='missing.txt'),'missing')
    def test_rejects_duplicate_binding_identity(self):
        self.check_bad(lambda d:d['bindings'].append(copy.deepcopy(d['bindings'][0])),'duplicate')
    def test_requires_explicit_scope_for_empty_bindings(self):
        self.check_bad(lambda d:d.update(bindings=[]),'empty')
    def test_rejects_invented_hardware_verification(self):
        self.check_bad(lambda d:d.update(hardware_tested=True),'hardware')
    def test_coverage_requires_exact_candidate_set_once_each(self):
        catalogue={'models':[dict(manufacturer='Brand',model='Device',source_grade='ready-for-extraction',sources=self.data['sources']),dict(manufacturer='Brand',model='Later',source_grade='partial')]}
        self.assertEqual(validate_catalogue_coverage([self.data],catalogue),[])
        self.assertTrue(validate_catalogue_coverage([],catalogue))
        self.assertTrue(validate_catalogue_coverage([self.data,self.data],catalogue))
        changed=copy.deepcopy(self.data);changed['model']='Later'
        self.assertTrue(validate_catalogue_coverage([changed],catalogue))
        changed=copy.deepcopy(self.data);changed['sources'][0]['sha256']='0'*64
        self.assertTrue(validate_catalogue_coverage([changed],catalogue))

if __name__=='__main__': unittest.main()
