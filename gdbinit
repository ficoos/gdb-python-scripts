# -*- ksh -*-
#
# If you use the GNU debugger gdb to debug the Python C runtime, you
# might find some of the following commands useful.  Copy this to your
# ~/.gdbinit file and it'll get loaded into gdb automatically when you
# start it up.  Then, at the gdb prompt you can do things like:
#
#    (gdb) pyo apyobjectptr
#    <module 'foobar' (built-in)>
#    refcounts: 1
#    address    : 84a7a2c
#    $1 = void
#    (gdb)

# Prints a representation of the object to stderr, along with the
# number of reference counts it current has and the hex address the
# object is allocated at.  The argument must be a PyObject*
define pyo
set $_unused_void = _PyObject_Dump($arg0)
end

# Prints a representation of the object to stderr, along with the
# number of reference counts it current has and the hex address the
# object is allocated at.  The argument must be a PyGC_Head*
define pyg
printf "%s\n" _PyGC_Dump($arg0)
end

# print the local variables of the current frame
define pylocals
    set $_i = 0
    while $_i < f->f_code->co_nlocals
	if f->f_localsplus + $_i != 0
	    set $_names = co->co_varnames
	    set $_name = PyString_AsString(PyTuple_GetItem($_names, $_i))
	    printf "%s:\n", $_name
            pyo f->f_localsplus[$_i]
	end
        set $_i = $_i + 1
    end
end


# A rewrite of the Python interpreter's line number calculator in GDB's
# command language
define lineno
    set $__continue = 1
#    set $__co = f->f_code
    set $__co = co
    #set $__lasti = f->f_lasti
    set $__sz = ((PyStringObject *)$__co->co_lnotab)->ob_size/2
    set $__p = (unsigned char *)((PyStringObject *)$__co->co_lnotab)->ob_sval
    set $__li = $__co->co_firstlineno
    set $__ad = 0
#    while ($__sz-1 >= 0 && $__continue)
#      set $__sz = $__sz - 1
#      set $__ad = $__ad + *$__p
#      set $__p = $__p + 1
#      if ($__ad > $__lasti)
#	set $__continue = 0
#      end
#      set $__li = $__li + *$__p
#      set $__p = $__p + 1
#    end
    printf "%d", $__li
end

# print the current frame - verbose
define pyframev
    pyframe
    pylocals
end

define pyframe
    set $__fn = (char *)((PyStringObject *)co->co_filename)->ob_sval
    set $__n = (char *)((PyStringObject *)co->co_name)->ob_sval
    printf "%s (", $__fn
    lineno
    printf "): %s\n", $__n
### Uncomment these lines when using from within Emacs/XEmacs so it will
### automatically track/display the current Python source line
#    printf "%c%c%s:", 032, 032, $__fn
#    lineno
#    printf ":1\n"
end

### Use these at your own risk.  It appears that a bug in gdb causes it
### to crash in certain circumstances.

#define up
#    up-silently 1
#    printframe
#end

#define down
#    down-silently 1
#    printframe
#end

define printframe
    if $pc > PyEval_EvalFrameEx && $pc < PyEval_EvalCodeEx
	pyframe
    else
        frame
    end
end

# Here's a somewhat fragile way to print the entire Python stack from gdb.
# It's fragile because the tests for the value of $pc depend on the layout
# of specific functions in the C source code.

# Explanation of while and if tests: We want to pop up the stack until we
# land in Py_Main (this is probably an incorrect assumption in an embedded
# interpreter, but the test can be extended by an interested party).  If
# Py_Main <= $pc <= Py_GetArgcArv is true, $pc is in Py_Main(), so the while
# tests succeeds as long as it's not true.  In a similar fashion the if
# statement tests to see if we are in PyEval_EvalFrameEx().

# Note: The name of the main interpreter function and the function which
# follow it has changed over time.  This version of pystack works with this
# version of Python.  If you try using it with older or newer versions of
# the interpreter you may will have to change the functions you compare with
# $pc.

# print the entire Python call stack
python
class pystack(gdb.Command):
    def __init__ (self):
        super (pystack, self).__init__ ("pystack", gdb.COMMAND_OBSCURE)
    def invoke(self, args, from_tty):
        frame = gdb.selected_frame()
        while True:
           frame = frame.older()
           if frame is None:
               break
           gdb.execute("up-silently")
           try:
              res = gdb.execute("pyframe")
              if res is not None:
                  print res
           except Exception:
              pass
        gdb.execute('select-frame 0')

pystack()
end


define pyrun
set $glock = PyGILState_Ensure()
call PyRun_SimpleString($arg0)
call PyGILState_Release($glock)
end

define pyrdbg
pyrun "import rpdb2; rpdb2.start_embedded_debugger(\"$arg0\")"
cont
end

python
class pyup(gdb.Command):
    def __init__ (self):
        super (pyup, self).__init__ ("pyup", gdb.COMMAND_OBSCURE)
    def invoke(self, args, from_tty):
        frame = gdb.selected_frame()
        while True:
           frame = frame.older()
           if frame is None:
               break
           gdb.execute("up-silently")
           try:
              res = gdb.execute("pyframe")
	      break
           except Exception:
              pass

pyup()
end

python
class pydown(gdb.Command):
    def __init__ (self):
        super (pydown, self).__init__ ("pydown", gdb.COMMAND_OBSCURE)
    def invoke(self, args, from_tty):
        frame = gdb.selected_frame()
        while True:
           frame = frame.newer()
           if frame is None:
               break
           gdb.execute("down-silently")
           try:
              res = gdb.execute("pyframe")
	      return
           except Exception:
              pass

pydown()
end


# print the entire Python call stack - verbose mode
define pystackv
    while $pc < Py_Main || $pc > Py_GetArgcArgv
        if $pc > PyEval_EvalFrameEx && $pc < PyEval_EvalCodeEx
	    pyframev
        end
        up-silently 1
    end
    select-frame 0
end

# generally useful macro to print a Unicode string
def pu
  set $uni = $arg0
  set $i = 0
  while (*$uni && $i++<100)
    if (*$uni < 0x80)
      print *(char*)$uni++
    else
      print /x *(short*)$uni++
    end
  end
end
