# Module-scope global variables

export
    CuGlobal, get, set


"""
    CuGlobal{T}(mod::CuModule, name::String)

Acquires a typed global variable handle from a named global in a module.
"""
struct CuGlobal{T}
    buf::Mem.Buffer

    function CuGlobal{T}(mod::CuModule, name::String) where T
        ptr_ref = Ref{Ptr{Cvoid}}()
        nbytes_ref = Ref{Cssize_t}()
        @apicall(:cuModuleGetGlobal, (Ptr{Ptr{Cvoid}}, Ptr{Cssize_t}, CuModule_t, Ptr{Cchar}), 
                                     ptr_ref, nbytes_ref, mod, name)
        if nbytes_ref[] != sizeof(T)
            throw(ArgumentError("size of global '$name' does not match type parameter type $T"))
        end
        buf = Mem.Buffer(ptr_ref[], nbytes_ref[], CuCurrentContext())

        return new{T}(buf)
    end
end

Base.cconvert(::Type{Ptr{Cvoid}}, var::CuGlobal) = var.buf

Base.:(==)(a::CuGlobal, b::CuGlobal) = a.handle == b.handle
Base.hash(var::CuGlobal, h::UInt) = hash(var.ptr, h)

"""
    eltype(var::CuGlobal)

Return the element type of a global variable object.
"""
Base.eltype(::Type{CuGlobal{T}}) where {T} = T

"""
    get(var::CuGlobal)

Return the current value of a global variable.
"""
function Base.get(var::CuGlobal{T}) where T
    val_ref = Ref{T}()
    @apicall(:cuMemcpyDtoH, (Ptr{Cvoid}, Ptr{Cvoid}, Csize_t),
                            val_ref, var.buf, var.buf.bytesize)
    return val_ref[]
end

"""
    set(var::CuGlobal{T}, T)

Set the value of a global variable to `val`
"""
function set(var::CuGlobal{T}, val::T) where T
    val_ref = Ref{T}(val)
    @apicall(:cuMemcpyHtoD, (Ptr{Cvoid}, Ptr{Cvoid}, Csize_t),
                            var.buf, val_ref, var.buf.bytesize)
end
