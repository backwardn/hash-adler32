// Copyright 2017 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build amd64

package adler32

import (
	"golang.org/x/sys/cpu"
)

// go:noescape
func updateSSE(d digest, p []byte) digest

func update(d digest, p []byte) digest {
	if cpu.X86.HasSSE41 {
		return updateSSE(d, p)
	}
	return updateGeneric(d, p)
}
