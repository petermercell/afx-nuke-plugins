// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Copyright (C) 2017, Ryan P. Wilson
//
//      Authority FX, Inc.
//      www.authorityfx.com

#ifndef AFX_MSVC_HACKS_H_
#define AFX_MSVC_HACKS_H_

// MSVC10 and earlier did not have C99 support. fmin and fmax functions were not available
// VS2015 and later have these in the standard library, so only define for older versions
#if defined(_WIN32) && defined(_MSC_VER) && (_MSC_VER < 1900)
  inline float fminf(float a, float b) {
    return std::min(a, b);
  }
  inline float fmaxf(float a, float b) {
    return std::max(a, b);
  }
#endif

#endif  // AFX_MSVC_HACKS_H_