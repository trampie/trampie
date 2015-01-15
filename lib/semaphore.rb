class Semaphore
    attr_reader :value, :max

    def initialize(count)
        @m = Mutex.new
        @value = count
        @waiting = []
    end

    def synchronize(*args)
        wait
        yield(*args)
    ensure
        signal
    end

    def wait
        queued = nil
        @m.synchronize do
            @value -= 1
            if @value < 0
                queued = @waiting << Thread.current
            end
        end
        Thread.stop if queued
    end

    def signal
        ready = nil
        @m.synchronize do
            if @value < 0
                ready = @waiting.shift
            end
            @value += 1
        end
        ready.run if ready
    end
end

class BoundedBuffer
    def initialize(size)
        @buffer = Array.new
        @filled = Semaphore.new 0
        @empty = Semaphore.new size
        @m = Mutex.new
    end

    def push(item)
        @empty.wait
        @m.synchronize {@buffer << item}
        @filled.signal
    end

    alias << push

    def shift
        @filled.wait
        item = @m.synchronize {@buffer.shift}
        @empty.signal
        item
    end

    def length
        @buffer.length
    end

    def to_s
        @buffer.to_s
    end
end

#Copyright (c) 2013 Alex Beal <alexlbeal@gmail.com>
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of
#this software and associated documentation files (the "Software"), to deal in
#the Software without restriction, including without limitation the rights to
#use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
#of the Software, and to permit persons to whom the Software is furnished to do
#so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.