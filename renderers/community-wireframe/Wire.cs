using System;
using System.IO;
using System.Linq;
using System.Net.Sockets;
using System.Text;

namespace CommunityWireframe
{
    internal sealed class Wire
    {
        internal const uint Capabilities = 29;
        private readonly byte[] token, session = Guid.NewGuid().ToByteArray();
        private bool negotiated;
        private ulong sequence;
        internal string Stage { get; private set; }
        internal uint Tick { get; private set; }
        internal uint Pause { get; private set; }

        internal Wire(string token)
        {
            if (token == null || token.Length != 32) throw new InvalidDataException("Expected launcher session token.");
            this.token = Enumerable.Range(0, 16).Select(index => Convert.ToByte(token.Substring(index * 2, 2), 16)).ToArray();
        }

        internal static byte[] Read(Stream stream, int size, bool allowEnd)
        {
            var bytes = new byte[size];
            for (int offset = 0; offset < size;)
            {
                int count;
                try { count = stream.Read(bytes, offset, size - offset); }
                catch (IOException error)
                {
                    var socket = error.InnerException as SocketException;
                    if (allowEnd && offset == 0 && socket != null && socket.SocketErrorCode == SocketError.ConnectionReset) return null;
                    throw;
                }
                if (count == 0)
                {
                    if (offset == 0 && allowEnd) return null;
                    throw new EndOfStreamException("Truncated presentation packet.");
                }
                offset += count;
            }
            return bytes;
        }

        internal static void Reply(Stream stream, uint operation, uint buttons, byte[] body)
        {
            using (var writer = new BinaryWriter(stream, Encoding.UTF8, true))
            {
                writer.Write((uint)body.Length + 4);
                writer.Write(operation | 0x80000000u);
                writer.Write(buttons);
                writer.Write(body);
            }
        }

        internal byte[] Hello(byte[] body)
        {
            Require(!negotiated && body.Length == 40, "Expected one 40-byte HELLO.");
            Require(U32(body, 0) == 0x3152474d && U32(body, 4) == 15 && U32(body, 8) == 30 && U32(body, 12) == 20,
                "Wireframe sample requires presentation protocol 15.30 / vertex stride 20.");
            uint offered = U32(body, 16), required = U32(body, 20);
            Require((required & ~offered) == 0 && (required & ~Capabilities) == 0 && (offered & Capabilities) == Capabilities,
                "Wireframe sample supports command/context mode, capabilities 0x1d; scene mode is unsupported.");
            int difference = 0;
            for (int index = 0; index < 16; ++index) difference |= body[24 + index] ^ token[index];
            Require(difference == 0, "Presentation session authentication failed.");
            negotiated = true;
            var result = new byte[28];
            Buffer.BlockCopy(new uint[] { 15, 30, Capabilities }, 0, result, 0, 12);
            Buffer.BlockCopy(session, 0, result, 12, 16);
            return result;
        }

        internal void Accept(uint operation)
        {
            Require(negotiated, "HELLO must precede presentation commands.");
            Require((operation >= 2 && operation <= 8) || operation == 11 || operation == 12,
                "Unnegotiated presentation operation: " + operation);
        }

        internal void Context(byte[] body)
        {
            Require(body.Length == 52 && U32(body, 0) == 2, "Expected session-bound context schema 2.");
            for (int index = 0; index < 16; ++index)
                Require(body[36 + index] == session[index], "Stale context session.");
            ulong next = BitConverter.ToUInt64(body, 8);
            Require(next == sequence + 1, "Native sample sequence is not contiguous.");
            sequence = next;
            Tick = U32(body, 16);
            Pause = U32(body, 20);
            string stage = Encoding.ASCII.GetString(body, 28, 8).TrimEnd('\0');
            if (stage != Stage) Console.WriteLine("PRESENTATION_CONTEXT stage=" + stage + " tick=" + Tick);
            Stage = stage;
        }

        internal static uint U32(byte[] bytes, int offset) { return BitConverter.ToUInt32(bytes, offset); }
        internal static int I32(byte[] bytes, int offset) { return BitConverter.ToInt32(bytes, offset); }
        internal static void Require(bool valid, string message)
        {
            if (!valid) throw new InvalidDataException(message);
        }
    }
}
