
// Copyright (C) 2012 R. Diez
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the Affero GNU General Public License version 3
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// Affero GNU General Public License version 3 for more details.
//
// You should have received a copy of the Affero GNU General Public License version 3
// along with this program. If not, see http://www.gnu.org/licenses/ .


// Include this header file only once.
#ifndef BMS_CIRCULAR_BUFFER_H_INCLUDED
#define BMS_CIRCULAR_BUFFER_H_INCLUDED

#include <stdint.h>
#include <assert.h>
#include <string.h>


// Fixed-size circular buffer.
//
// This class is designed for embedded environments, where speed is essential.
// There is no error handling, only asserts, so the caller must always check
// before making erroneous calls. For example, the caller must not try
// to read an element if the buffer is empty.
//
// There is no automatic multithread or interrupt protection, the caller
// must manage that too if needed.
//
// If code size is important, you can make MAX_ELEM_COUNT a class member
// instead of a template parameter, but then the modulo operations cannot be
// optimised at compilation time.
//
// If your processor supports virtual memory, you can map the buffer's memory
// twice into consecutive memory locations and avoid handling wrap-arounds in many occasions.


template< typename TemplElemType,
          typename TemplSizeType,
          TemplSizeType MAX_ELEM_COUNT >

class CCircularBuffer  // Also called Cyclic or Ring Buffer in the literature.
{
 public:
  // This is so that the user can use these typenames too.
  typedef TemplElemType ElemType;
  typedef TemplSizeType SizeType;

 private:
  ElemType  m_buffer[ MAX_ELEM_COUNT ];
  SizeType  m_readPos;
  SizeType  m_elemCount;


  // Use our own min() routine, because Atmel Software Framework version 3.7.3.69
  // defines min and max macros, which conflict with STL's std::min and std::max.

  template < typename IntegerType >
  static
  IntegerType MinFrom ( const IntegerType a, const IntegerType b )
  {
    return a < b ? a : b;
  }

 public:
  CCircularBuffer ( void )
  {
    Reset();
  }

  void Reset ( void )
  {
    m_readPos   = 0;
    m_elemCount = 0;
  }

  SizeType GetElemCount ( void ) const { return m_elemCount; }
  SizeType GetFreeCount ( void ) const { return MAX_ELEM_COUNT - m_elemCount; }
  bool     IsEmpty      ( void ) const { return GetElemCount() == 0; }
  bool     IsFull       ( void ) const { return GetFreeCount() == 0; }


  // Peeking does not consume the element, see ConsumeReadElements() below.

  const ElemType * PeekElement ( void ) const
  {
    assert( !IsEmpty() );
    assert( m_readPos < MAX_ELEM_COUNT );
    return &m_buffer[ m_readPos ];
  }


  // This routine is convenient but slow, as it copies the elements
  // to another memory location. If speed is important, use
  // GetReadPtr() instead for large amounts of data.

  void PeekMultipleElements ( const SizeType elemCount,
                              ElemType * const elemArray ) const
  {
    assert( elemCount > 0 );
    assert( elemCount <= GetElemCount() );

    SizeType elemCountLeft = elemCount;
    ElemType * dest = elemArray;

    // Do the first chunk.

    SizeType firstChunkMaxCount;
    const ElemType * firstChunkPtr = GetReadPtr( &firstChunkMaxCount );

    assert( firstChunkMaxCount > 0 );

    const SizeType firstLoopCount = MinFrom( firstChunkMaxCount, elemCountLeft );

    for ( SizeType i = 0; i < firstLoopCount; ++i )
    {
      *dest = firstChunkPtr[i];
      ++dest;
    }

    elemCountLeft -= firstLoopCount;


    // Do the second chunk, if any.

    if ( elemCountLeft > 0 )
    {
      assert( elemCountLeft < MAX_ELEM_COUNT );

      for ( SizeType j = 0; j < elemCountLeft; ++j )
      {
        *dest = m_buffer[ j ];
        ++dest;
      }
    }

    assert( dest == elemArray + elemCount );
  }


  ElemType ReadElement ( void )
  {
    const ElemType elem = *PeekElement();
    ConsumeReadElements( 1 );
    return elem;
  }


  // The value returned in *elemCount is the maximum number of consecutive elements
  // that can be read at the returned memory location. Note that it can zero,
  // and it can also be less than the number of elements in the buffer (the circular buffer
  // may wrap around), so you may need to call this routine a second time in order
  // to read all available elements.
  // It is recommended that you call this routine in a loop, in case a future circular
  // buffer implementation needs more than 2 calls.
  // After calling this routine a second time, remember to call ConsumeReadElements() beforehand.

  const ElemType * GetReadPtr ( SizeType * const elemCount ) const
  {
    *elemCount = MinFrom( m_elemCount, MAX_ELEM_COUNT - m_readPos );
    assert( m_readPos < MAX_ELEM_COUNT );
    return &m_buffer[ m_readPos ];
  }

  void ConsumeReadElements ( const SizeType elemCountToConsume )
  {
    assert( elemCountToConsume != 0 );
    assert( elemCountToConsume <= m_elemCount );

    m_readPos += elemCountToConsume;
    m_readPos %= MAX_ELEM_COUNT;
    m_elemCount -= elemCountToConsume;
  }


  void WriteElem ( const ElemType elemToWrite )
  {
    assert( !IsFull() );

    const SizeType writePos = ( m_readPos + m_elemCount ) % MAX_ELEM_COUNT;
    m_buffer[ writePos ] = elemToWrite;
    ++m_elemCount;
  }


  // This routine is convenient but slow, as it copies the elements
  // from another memory location. If speed is important, use
  // GetWritePtr() instead for large amounts of data, so that
  // you can write data directly into the buffer.

  void WriteElemArray ( const ElemType * const ptr, const SizeType elemCount )
  {
    assert( elemCount > 0 );
    assert( elemCount <= GetFreeCount() );

    // We do not really need a loop here, as there will be exactly
    // one or two iterations, but this is a good example of how
    // the user should write such a loop, in case a future implementation
    // does need more iterations.

    const ElemType * src = ptr;
    SizeType elemCountLeft = elemCount;

    do
    {
      SizeType maxChunkElemCount;
      ElemType * const writePtr = GetWritePtr( &maxChunkElemCount );

      const SizeType loopCount = MinFrom( maxChunkElemCount, elemCountLeft );

      for ( SizeType i = 0; i < loopCount; ++i )
      {
        writePtr[i] = *src;
        ++src;
      }

      CommitWrittenElements( loopCount );
      elemCountLeft -= loopCount;
    }
    while ( elemCountLeft > 0 );

    assert( src == ptr + elemCount );
  }


  // This routine boldly assumes that the element type can hold a string character.
  // The null terminator is not placed in the buffer.

  void WriteString ( const char * const str )
  {
    // We could optimise this routine so that we do not need to call strlen() upfront.
    const size_t len = strlen( str );
    if ( len > 0 )
      WriteElemArray( (const ElemType *)str, len );
  }


  // The value returned in *elemCount is the maximum number of consecutive elements
  // that can be written at the returned memory location. Note that it can zero, and it can also
  // be less than the number of elements that would fit in the buffer (the circular buffer
  // may wrap around), so you may need to call this routine a second time in order
  // to fill up the whole buffer.
  // It is recommended that you call this routine in a loop, in case a future circular
  // buffer implementation needs more than 2 calls.
  // After calling this routine a second time, remember to call CommitWrittenElements() beforehand.

  ElemType * GetWritePtr ( SizeType * const elemCount )
  {
    const SizeType writePos = ( m_readPos + m_elemCount ) % MAX_ELEM_COUNT;
    assert( writePos < MAX_ELEM_COUNT );

    ElemType * const ptr = &m_buffer[ writePos ];

    *elemCount = MinFrom( MAX_ELEM_COUNT - m_elemCount,  // Room left in the buffer ...
                          MAX_ELEM_COUNT - writePos      // ... without wrapping around.
                        );
    return ptr;
  }

  void CommitWrittenElements ( const SizeType elemCountToCommit )
  {
    assert( elemCountToCommit != 0 );
    assert( elemCountToCommit <= GetFreeCount() );
    m_elemCount += elemCountToCommit;
  }
};

#endif  // Include this header file only once.
