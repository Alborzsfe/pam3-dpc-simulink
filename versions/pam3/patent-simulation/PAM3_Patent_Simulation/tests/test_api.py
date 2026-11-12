import json,threading,unittest,urllib.request,urllib.error
from http.server import HTTPServer
from app import Handler

class APITests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server=HTTPServer(('127.0.0.1',0),Handler)
        cls.thread=threading.Thread(target=cls.server.serve_forever,daemon=True)
        cls.thread.start();cls.url=f'http://127.0.0.1:{cls.server.server_port}'
    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown();cls.server.server_close();cls.thread.join(timeout=3)
    def post(self,p,origin=None):
        headers={'Content-Type':'application/json'}
        if origin:headers['Origin']=origin
        req=urllib.request.Request(self.url+'/api/simulate',data=json.dumps(p).encode(),headers=headers)
        return json.load(urllib.request.urlopen(req,timeout=15))
    def test_actual_new_simulation_two_channels_four_methods(self):
        p={'symbols':512,'snr_db':40,'gain':1,'dc_offset':0,'clock_ppm':1000,'seed':128}
        r=self.post(p)
        self.assertEqual(len(r['metrics']),8)
        for row in r['metrics']:
            self.assertEqual(row['n_evaluated'],472)
            if row['method']=='patent_fixed_bypass':self.assertEqual(row['errors'],0)
        r2=self.post({**p,'snr_db':5})
        a=next(x for x in r['metrics'] if x['channel']=='master' and x['method']=='patent_fixed_bypass')
        b=next(x for x in r2['metrics'] if x['channel']=='master' and x['method']=='patent_fixed_bypass')
        self.assertGreater(b['errors'],a['errors'])
    def test_invalid_requests_rejected(self):
        for p in [{'symbols':1},{'symbols':float('inf')},{'gain':10},['bad']]:
            with self.assertRaises(urllib.error.HTTPError) as c:self.post(p)
            self.assertEqual(c.exception.code,400)
    def test_unrelated_web_origin_rejected(self):
        with self.assertRaises(urllib.error.HTTPError) as c:self.post({'symbols':256},origin='https://example.com')
        self.assertEqual(c.exception.code,403)
    def test_saved_dashboard_served(self):
        with urllib.request.urlopen(self.url,timeout=5) as r:
            body=r.read();self.assertIn(b'PAM-3',body);self.assertIn(b'canvas',body)

if __name__=='__main__':unittest.main()
