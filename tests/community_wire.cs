using System;
using System.IO;
using CommunityWireframe;

internal static class CommunityWireTest
{
    private static void Require(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
    }

    private static void Reject(Action action)
    {
        try { action(); }
        catch (InvalidDataException) { return; }
        throw new InvalidOperationException("Invalid wire data was accepted");
    }

    private static byte[] Words(params uint[] words)
    {
        var bytes = new byte[words.Length * 4];
        Buffer.BlockCopy(words, 0, bytes, 0, bytes.Length);
        return bytes;
    }

    private static void Negotiation()
    {
        var wire = new Wire(new string('0', 32));
        var hello = new byte[40];
        Buffer.BlockCopy(Words(0x3152474d, 15, 30, 20, UInt32.MaxValue, 29), 0, hello, 0, 24);
        Reject(() => wire.Accept(7));
        byte[] reply = wire.Hello(hello);
        Require(reply.Length == 28 && Wire.U32(reply, 8) == 29, "Wrong negotiated capabilities");
        Reject(() => wire.Hello(hello));
        Reject(() => wire.Accept(16));
        var context = new byte[52];
        Buffer.BlockCopy(Words(2, 1, 1, 0, 42, 1, 0), 0, context, 0, 28);
        Buffer.BlockCopy(reply, 12, context, 36, 16);
        wire.Context(context);
        Require(wire.Tick == 42 && wire.Pause == 1, "Native context was lost");
        Reject(() => wire.Context(context));
        hello[4] = 16;
        Reject(() => new Wire(new string('0', 32)).Hello(hello));
        hello[4] = 15; hello[24] = 1;
        Reject(() => new Wire(new string('0', 32)).Hello(hello));
        hello[24] = 0; hello[20] = 255;
        Reject(() => new Wire(new string('0', 32)).Hello(hello));
    }

    private static void Readback()
    {
        using (var surface = new Surface())
        {
            var upload = new byte[24];
            Buffer.BlockCopy(Words(10, 20, 2, 1), 0, upload, 0, 16);
            byte[] pixels = { 1, 2, 3, 4, 255, 0, 127, 0 };
            Buffer.BlockCopy(pixels, 0, upload, 16, 8);
            surface.Upload(upload);
            surface.Move(Words(10, 20, 2, 1, 11, 20));
            Require(Convert.ToBase64String(surface.Read(Words(11, 20, 2, 1))) == Convert.ToBase64String(pixels), "Overlapping MOVE or RGBA readback changed source pixels");
            Reject(() => surface.Read(Words(1024, 0, 1, 1)));
            Reject(() => surface.Upload(Words(0, 0, 1, 1)));
            Reject(() => surface.Draw(new byte[72]));
        }
        using (var truncated = new MemoryStream(new byte[3]))
        {
            try { Wire.Read(truncated, 8, true); }
            catch (EndOfStreamException) { return; }
            throw new InvalidOperationException("Truncated frame was accepted");
        }
    }

    public static int Main()
    {
        Negotiation();
        Readback();
        Console.WriteLine("COMMUNITY_WIRE_TEST failures=0");
        return 0;
    }
}
