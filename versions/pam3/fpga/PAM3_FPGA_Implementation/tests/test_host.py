import unittest
from host_decode import records_to_frames

def record(symbols,frame=0,channel=0,last=True):
    data=sum((s&3)<<(2*i) for i,s in enumerate(symbols))
    return data|(len(symbols)<<64)|(channel<<71)|(int(last)<<72)|(frame<<73)

class HostTests(unittest.TestCase):
    def test_two_channels_multirecord_empty_and_full(self):
        words=[record([-1,0,1]*10+[0,1],last=False),record([],channel=1),record([-1],last=True),
               record([],frame=1),record([1,0,-1],frame=1,channel=1)]
        d=records_to_frames(words)
        self.assertEqual(d[(0,0)],[-1,0,1]*10+[0,1,-1]);self.assertEqual(d[(1,0)],[])
    def test_illegal_code(self):
        with self.assertRaises(ValueError):records_to_frames([record([2])])
    def test_bad_count(self):
        with self.assertRaises(ValueError):records_to_frames([(33<<64)|(1<<72)])
    def test_reserved(self):
        with self.assertRaises(ValueError):records_to_frames([record([])|(1<<105)])
    def test_padding(self):
        with self.assertRaises(ValueError):records_to_frames([record([0])|4])
    def test_truncated(self):
        with self.assertRaises(ValueError):records_to_frames([record([1],last=False)])
    def test_frame_order(self):
        with self.assertRaises(ValueError):records_to_frames([record([],frame=1)])
    def test_after_terminal(self):
        with self.assertRaises(ValueError):records_to_frames([record([]),record([0])])

if __name__=='__main__':unittest.main()
