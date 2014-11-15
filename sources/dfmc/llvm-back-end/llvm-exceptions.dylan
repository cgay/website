Module: dfmc-llvm-back-end
Copyright:    Original Code is Copyright (c) 1995-2004 Functional Objects, Inc.
              Additional code is Copyright 2009-2013 Gwydion Dylan Maintainers
              All rights reserved.
License:      See License.txt in this distribution for details.
Warranty:     Distributed WITHOUT WARRANTY OF ANY KIND

// Arithmetic exceptions transfer control to the C call-ins defined
// here. Their job is then to signal an appropriate error.

define c-callable auxiliary &runtime-primitive-descriptor dylan-integer-overflow-error () => ();
  op--call-error-iep(be, #"machine-word-overflow");
end;

define c-callable auxiliary &runtime-primitive-descriptor dylan-integer-divide-by-0-error () => ();
  op--call-error-iep(be, #"integer-divide-by-0");
end;

define c-callable auxiliary &runtime-primitive-descriptor dylan-float-divide-by-0-error () => ();
  op--call-error-iep(be, #"float-divide-by-0");
end;

define c-callable auxiliary &runtime-primitive-descriptor dylan-float-overflow-error () => ();
  op--call-error-iep(be, #"float-overflow")
end;

define c-callable auxiliary &runtime-primitive-descriptor dylan-float-underflow-error () => ();
  op--call-error-iep(be, #"float-underflow")
end;

