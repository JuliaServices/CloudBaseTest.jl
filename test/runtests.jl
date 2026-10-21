using CloudBaseTest, CloudBase, Test, HTTP, Sockets, Random
using CloudBase: AWS, Azure

const x32bit = Sys.WORD_SIZE == 32

@testset "Concurrent Minio/Azurite test servers" begin
    mconfigs = Vector{Any}(undef, 10)
    aconfigs = Vector{Any}(undef, 10)
    @sync for i = 1:10
        @async Minio.with(bindIP="127.0.0.1", startupDelay=0.5) do conf
            mconfigs[i] = conf
            credentials, bucket = conf
            csv = "a,b,c\n1,2,3\n4,5,$(rand())"
            AWS.put("$(bucket.baseurl)test.csv", [], csv; service="s3", credentials)
            resp = AWS.get("$(bucket.baseurl)test.csv"; service="s3", credentials)
            @test String(resp.body) == csv
        end
        if !x32bit
            @async Azurite.with(startupDelay=0.5) do conf
                aconfigs[i] = conf
                credentials, container = conf
                csv = "a,b,c\n1,2,3\n4,5,$(rand())"
                Azure.put("$(container.baseurl)test", ["x-ms-blob-type" => "BlockBlob"], csv; credentials)
                resp = Azure.get("$(container.baseurl)test"; credentials)
                @test String(resp.body) == csv
            end
        end
    end
    for i = 1:10
        @test !isdir(mconfigs[i].dir)
        @test success(mconfigs[i].process)
        if !x32bit
            @test !isdir(aconfigs[i].dir)
            @test success(aconfigs[i].process)
        end
    end
end

# test debug logs are printed for azurite
@testset "Azurite debug" begin
    log = Ref{String}()
    @test_throws HTTP.StatusError Azurite.with(debug=true, debugLog=log) do conf
        credentials, container = conf
        csv = "a,b,c\n1,2,3\n4,5,$(rand())"
        # this will error since we don't have credentials
        Azure.put("$(container.baseurl)test", ["x-ms-blob-type" => "BlockBlob"], csv)
    end
    @test !isempty(log[])
end

@testset "emulator command preparation" begin
    tool = addenv(`$(Base.julia_cmd()) --startup-file=no -e 'print(ENV["CLOUDBASE_CMD_TEST"])'`,
        "CLOUDBASE_CMD_TEST" => "command environment preserved")
    storage, environment = tool.exec, tool.env
    original = copy(storage)
    @test CloudBaseTest._cmd(tool) === tool
    @test tool.exec === storage
    @test tool.env === environment
    @test tool.exec[end-length(original)+1:end] == original
    @test length(tool.exec) in (length(original), length(original) + 1)
    @test read(tool, String) == "command environment preserved"
end

@testset "_wait_for_port" begin
    port, socket = Sockets.listenany(IPv4(0), rand(RandomDevice(), 10000:50000))
    try
        _, duration = @timed CloudBaseTest._wait_for_port("127.0.0.1", port, 1)
        @test duration < 1
    finally
        close(socket)
    end
    refused_port = 54523
    @test_throws ErrorException CloudBaseTest._wait_for_port("127.0.0.1", refused_port, 0)

    _, duration = @timed @test_throws ErrorException CloudBaseTest._wait_for_port("127.0.0.1", refused_port, 1)
    @test duration < 2
    # Unreachable network
    _, duration = @timed @test_throws Base.IOError CloudBaseTest._connect_with_timeout("224.0.0.1", refused_port, 1)
    @test duration < 2
end
