
t0=time()
# Start an async task
t = @async begin
    sleep(2.0)
    return pi
end

# Control comes here immediately
println("Started ", t)

# wait for its completion
resp = wait(t)
println("Response : ", resp, " after ", time()-t0, " seconds")

# @sync waits for all enclosed async operations to complete
t0=time()
@sync begin
    for i in 1:100
        @async (sleep(1.0); print("$i.."))
    end
end
println("\n\n All tasks finished in ", time() - t0, " seconds")

# compute-bound or blocking ccalls do not yield
t0=time()
@sync begin
    for i in 1:5
        @async begin
            ccall(:sleep, Cint, (Cint,), 1.0)
            print("$i..")
        end
    end
end
println("\n\n All tasks finished in ", time() - t0, " seconds")

a=1

# @async localizes variables
@async (sleep(2.0); println("@async : ", a))

# @schedule does not
@schedule (sleep(2.0); println("@schedule : ", a))

a="Hello";


function producer(cnt)
    @schedule begin
        for i in 1:cnt
            produce(i)
        end
        println("Producer DONE!")
    end
end

function consumer(t, id)
    @schedule begin
        sleep(1.0)
        while !istaskdone(t)
            v = consume(t)
            (v != nothing) && println("consumer $id ===> $v")
        end
        println("consumer $id DONE!")
    end
end

# start a producer task
t=producer(6);

# start consumers
consumer(t, 1);
consumer(t, 2);
consumer(t, 3);

# start a producer task
t=producer(6);

for v in t
    println("consumed $v")
end

c=Channel{Int64}(100)
for i in 1:6
    put!(c, i)
end

@schedule begin 
    for v in c
        println(v)
    end
    println("Consumer task DONE!")
end;


close(c);

nprocs() > 1 && rmprocs(workers(); waitfor=0.5)
addprocs(4)
@parallel (+) for i in 1:100
    rand(Bool)
end
@time @parallel (+) for i in 1:10^8
    rand(Bool)
end

nprocs() > 1 && rmprocs(workers(); waitfor=0.5)
addprocs(4)
files = filter(x->endswith(x, ".jl"), readdir("/Users/amitm/Julia/julia/base"))

# compilation run
pmap(x->begin
        path=joinpath("/Users/amitm/Julia/julia/base",x)
        readall(`md5 $path`)
    end, files);

# timed run
@time pmap(x->begin
        path=joinpath("/Users/amitm/Julia/julia/base",x)
        # simulate compute time by calculating MD5 a few times
        for i in 1:5
            readall(`md5 $path`)
        end
        readall(`md5 $path`)
    end, files)

nprocs() > 1 && rmprocs(workers(); waitfor=0.5)
addprocs(4)

jobs_c = RemoteRef(()->Channel(100))
results_c = RemoteRef(()->Channel(100))

# define function on all workers
@everywhere function do_some_work(jobs_c, results_c)
    println("Worker task started.")
    while true
        try
            rqst = take!(jobs_c)
            if rqst == :EXIT
                break
            else
                sleep(rqst)
                put!(results_c, (myid(), rqst))
            end
        catch e
            println(e)
        end
    end
    println("DONE!")
end

# start the worker tasks....
for p in workers()
    remotecall(p, do_some_work, jobs_c, results_c)
end

# adding jobs....
jobs = rand(1:10, 30)
for i in jobs
    put!(jobs_c, i)
end

# Have the worker tasks exit at the end
for i in 1:nworkers()
    put!(jobs_c, :EXIT)
end

for i in 1:length(jobs)
    (wrkr, data) = take!(results_c) 
    println("worker $wrkr : ", data)
end

nprocs() > 1 && rmprocs(workers(); waitfor=0.5)
addprocs(4)

# execute expression on all processors
@everywhere println(myid())

rr = remotecall(workers()[1], ()->(sleep(1.0); pi))
isready(rr)

fetch(rr)

take!(rr)

isready(rr)

nprocs() > 1 && rmprocs(workers(); waitfor=0.5)
addprocs(4)

# @spawn cycles through all workers
fetch(@spawn myid())

rr = RemoteRef(()->Channel{AbstractString}(2), workers()[1])
put!(rr, "Hello")

put!(rr, 2)

put!(rr, "World")

# should be ready
isready(rr)

# take the first element
take!(rr)

# and then the next
take!(rr)

# should not be ready
isready(rr)

p1 = workers()[1]

p2 = workers()[2]

rr = RemoteRef(p1)

put!(rr, "put! from $(myid())")

remotecall_fetch(p2, r->(println(take!(r)); put!(r, "put! from $(myid())"); nothing), rr)

fetch(rr)
