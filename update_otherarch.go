// Copyright 2017 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package adler32

// Add p to the running checksum d.
func updateGeneric(d digest, p []byte) digest {
	s1, s2 := uint32(d&0xffff), uint32(d>>16)
	for len(p) > 0 {
		var q []byte
		if len(p) > nmax {
			p, q = p[:nmax], p[nmax:]
		}
		for len(p) >= 4 {
			s1 += uint32(p[0])
			s2 += s1
			s1 += uint32(p[1])
			s2 += s1
			s1 += uint32(p[2])
			s2 += s1
			s1 += uint32(p[3])
			s2 += s1
			p = p[4:]
		}
		for _, x := range p {
			s1 += uint32(x)
			s2 += s1
		}
		s1 %= mod
		s2 %= mod
		p = q
	}
	return digest(s2<<16 | s1)
}
