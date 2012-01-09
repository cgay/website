Module: dfmc-llvm-back-end
Copyright:    Original Code is Copyright (c) 1995-2004 Functional Objects, Inc.
              Additional code is Copyright 2009-2011 Gwydion Dylan Maintainers
              All rights reserved.
License:      See License.txt in this distribution for details.
Warranty:     Distributed WITHOUT WARRANTY OF ANY KIND

/// Temporary values

define thread variable *temporary-value-table* = false-or(<object-table>) = #f;

define method temporary-value
    (temporary :: <temporary>) => (value :: type-union(<llvm-value>, <pair>));
  element(*temporary-value-table*, temporary, default: #f)
    | error("No value defined for temporary %s (generator %=)",
            temporary, temporary.generator)
end method;

define method temporary-value-setter
    (value :: type-union(<llvm-value>, <pair>), temporary :: <temporary>)
 => (value :: type-union(<llvm-value>, <pair>));
  if (element(*temporary-value-table*, temporary, default: #f))
    error("Temporary %s is already set", temporary)
  else
    *temporary-value-table*[temporary] := value
  end if
end method;

define thread variable *merge-operands-table* :: false-or(<object-table>) = #f;

define method merge-operands-setter
    (operands :: <stretchy-vector>, temporary :: <temporary>)
 => (operands :: <stretchy-vector>);
  if (element(*merge-operands-table*, temporary, default: #f))
    error("Merge operands for %s is already set", temporary)
  else
    *merge-operands-table*[temporary] := operands
  end if
end method;

define method add-merge-operands
    (temporary :: <temporary>, value :: <llvm-value>, bb :: <llvm-value>)
 => ()
  let operands = *merge-operands-table*[temporary];
  add!(operands, value);
  add!(operands, bb);
end method;


/// Code emission

define method emit-code
    (back-end :: <llvm-back-end>, module :: <llvm-module>, o,
     #key init? = #f)
 => ();
  // Do nothing
end method;

define method emit-code
    (back-end :: <llvm-back-end>, module :: <llvm-module>, o :: <&iep>,
     #key init? = #f)
 => ();
  unless (code(o))
    let function-name = emit-name(back-end, module, o);
    let function-type = llvm-lambda-type(back-end, o);

    let parameter-types = function-type.llvm-function-type-parameter-types;
    let arguments
      = map(method (arg-type, index, param)
              make(<llvm-argument>,
                   type: arg-type,
                   name: hygienic-mangle(back-end,
                                         param.name, param.frame-offset),
                   index: index)
            end,
            parameter-types,
            range(below: parameter-types.size),
            parameters(o));

    let linkage
      = if (o.model-definition & ~init?) #"external" else #"internal" end;
    let section
      = if (init?) #"init-code" else #"code" end;

    block ()
      o.code
        := back-end.llvm-builder-function
        := make(<llvm-function>,
                name: function-name,
                type: llvm-pointer-to(back-end, function-type),
                arguments: arguments,
                linkage: linkage,
                section: llvm-section-name(back-end, section),
                calling-convention:
                  llvm-calling-convention(back-end, o));

      // Emit the entry block
      ins--block(back-end, make(<llvm-basic-block>, name: "bb.entry"));

      dynamic-bind (*temporary-value-table* = make(<object-table>),
                    *merge-operands-table* = make(<object-table>))
        // Add function arguments to the function's value table,
        // and to the temporary value mapping
        for (argument in arguments, param in parameters(o))
          ins--local(back-end, argument.llvm-argument-name, argument);
          temporary-value(param) := argument;
        end for;

        // Emit debug information for the function
        emit-lambda-dbg-function(back-end, o);

        // Emit definitions for temporaries
        let e :: <lambda-lexical-environment> = o.environment;
        for (tmp in e.temporaries)
          if (used?(tmp))
            emit-local-definition(back-end, tmp);
          end if;
        end for;

        // Emit the body of the function
        emit-computations(back-end, module, o.body, #f);
      end dynamic-bind;
    cleanup
      back-end.llvm-builder-dbg := #f;
      back-end.llvm-builder-function := #f;
    EXCEPTION (e :: <error>)    // FIXME
      back-end.llvm-builder-basic-block := #f;
      back-end.llvm-builder-function.llvm-function-basic-blocks.size := 0;
      remove-all-keys!(back-end.llvm-builder-function.llvm-function-value-table);
      ins--block(back-end, make(<llvm-basic-block>, name: "bb.entry"));
      ins--ret(back-end, emit-reference(back-end, module, #x4300430));
      format(*standard-output*, "emit %s: %s\n", function-name, e);
      force-output(*standard-output*);
    end block;

    // Done with this DFM?
    if (*retract-dfm?*)
      if (lambda-top-level?(o))
	retract-method-dfm(o);
	retract-method-dfm(o.function);
      end if;
    end if;
  end unless;
end method;

// Calling convention for ordinary functions
define method llvm-calling-convention
    (back-end :: <llvm-back-end>, o :: <&iep>)
 => (calling-convention :: <integer>);
  $llvm-calling-convention-fast
end method;

// Calling convention for shared entry points
define method llvm-calling-convention
    (back-end :: <llvm-back-end>, o :: <&shared-entry-point>)
 => (calling-convention :: <integer>);
  $llvm-calling-convention-fast
end method;
