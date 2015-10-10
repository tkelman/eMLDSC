
# *** Matric Access. ***
const SIZE=10000

function foo()
    x = rand(SIZE, SIZE)
    sum = 0.0
    @time for i=1:SIZE
        for j=1:SIZE
            sum += x[i, j]
        end
    end
    sum
end

function bar()
    x = rand(SIZE, SIZE)
    sum = 0.0
    @time for i=1:SIZE
        for j=1:SIZE
            sum += x[j, i]
        end
    end
    sum
end

foo()

bar()

# *** Immutable Types ***

type P
   x::Int
   y::Int
end

immutable Q
   x::Int
   y::Int
end

function compare(N)
    @time x = [P(rand(Int), rand(Int)) for i=1:N]
    @time y = [Q(rand(Int), rand(Int)) for i=1:N]

    @time for i=1:N x[i] end
    @time for i=1:N y[i] end
end

compare(10^7)

# *** Preallocation ***

function arrwithpush(N)
    y = Q[]
    for i=1:N push!(y, Q(rand(Int), rand(Int))) end
    y
end

function arrwithalloc(N)
    y = Array(Q, N)
    for i=1:N y[i] = Q(rand(Int), rand(Int)) end
    y
end

function compareprealloc(N)
    @time arrwithpush(N)
    @time arrwithalloc(N)
end

compareprealloc(SIZE);

# Preallocate outputs

function xinc(x)
    return [x, x+1, x+2]
end

function loopinc()
    y = 0
    for i = 1:10^7
        ret = xinc(i)
        y += ret[2]
    end
    y
end

function xinc!{T}(ret::AbstractVector{T}, x::T)
    ret[1] = x
    ret[2] = x+1
    ret[3] = x+2
    nothing
end

function loopinc_prealloc()
    ret = Array(Int, 3)
    y = 0
    for i = 1:10^7
        xinc!(ret, i)
        y += ret[2]
    end
    y
end

function compare_preallocops()
    @time loopinc()
    @time loopinc_prealloc()
end

compare_preallocops()

# *** Performance Annotation ***
function inner( x, y )
    s = zero(eltype(x))
    for i=1:length(x)
        @inbounds s += x[i]*y[i]
    end
    s
end

function innersimd( x, y )
    s = zero(eltype(x))
    @simd for i=1:length(x)
        @inbounds s += x[i]*y[i]
    end
    s
end

function timeit( n, reps )
    x = rand(Float32,n)
    y = rand(Float32,n)
    s = zero(Float64)
    time = @elapsed for j in 1:reps
        s+=inner(x,y)
    end
    println("GFlop        = ",2.0*n*reps/time*1E-9)
    time = @elapsed for j in 1:reps
        s+=innersimd(x,y)
    end
    println("GFlop (SIMD) = ",2.0*n*reps/time*1E-9)
end

timeit(1000, 1000)

# *** Subnormal numbers as 0 *** 

function timestep( b, a, Δt )
    @assert length(a)==length(b)
    n = length(b)
    b[1] = 1                            # Boundary condition
    for i=2:n-1
        b[i] = a[i] + (a[i-1] - 2*a[i] + a[i+1]) * Δt
    end
    b[n] = 0                            # Boundary condition
end

function heatflow( a, nstep::Integer )
    b = a[:]
    for t=1:div(nstep,2)                # Assume nstep is even
        timestep(b,a,0.1)
        timestep(a,b,0.1)
    end
end

heatflow(zeros(10),2)           # Force compilation

for trial=1:6
    a = zeros(Float32,1000)
    Base.set_zero_subnormals(iseven(trial))  # Odd trials use strict IEEE arithmetic
    @time heatflow(a,1000)
end







# Profiling

Profile.clear()

@profile timeit(1000, 1000)

Profile.print()


