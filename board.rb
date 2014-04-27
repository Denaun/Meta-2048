require 'matrix'

class Array
  def reverse_each_with_index &block
    (0...length).reverse_each do |i|
      block.call self[i], i
    end
  end

  def deep_copy()
    Marshal.load( Marshal.dump( self ) )
  end
end

class Board
  def initialize(size)
    # Bad
    if size.is_a?(Array)
      @board = size
    else
      @board = Array.new(size) { Array.new(size) }
    end
  end

  def deep_copy
    Board.new(@board.deep_copy)
  end

  def [](row, col)
    @board[row][col]
  end

  def []=(row, col, val)
    @board[row][col] = val
  end

  def ==(other)
    other == @board
  end

  def size
    @board.size
  end

  def n_elem
    self.size ** 2
  end

  def max
    # @board.map(&:compact).map(&:max).max
    @board.flatten.compact.max
  end

  def empty_count
    @board.flatten.count(nil)
  end

  def monotonicity
    # This monotonicity is intended as a sort of similarity between the board
    # and a plane with the gradient pointing at the top corner
    
    corners = Matrix[[@board.first.first, @board.first.last],
                     [@board.last.first, @board.last.last]]
    corners_flat = corners.to_a.flatten.compact

    # Nothing on a corner: no sense for this monotonicity
    return 0 if corners_flat.empty?

    best_corner = corners.index(corners_flat.max) * (@board.size-1)
    best_corner_distance = best_corner.reduce(:+)
    ideal_corner_value = Math.log2(self.max)

    monotonicity = 0
    @board.each_with_index do |row, row_idx|
      row.each_with_index do |val, col_idx|
        val = 1 if val.nil?

        distance_from_corner = best_corner_distance - [row_idx, col_idx].reduce(:+)

        expected_value = [ideal_corner_value - distance_from_corner, 0].max
        actual_value = Math.log2(val)

        monotonicity += 1.0 / ((expected_value-actual_value).abs + 1)
      end
    end

    return monotonicity
  end

  def monotonicity2
    horizontal_count = {-1 => 0, 0 => 0, 1 => 0}
    @board.each do |row|
      row.each_cons(2) do |(first, second)|
        first = 1 if first.nil?
        second = 1 if second.nil?

        horizontal_count[first <=> second] += (Math.log2(first) - Math.log2(second)).abs
      end
    end

    vertical_count = {-1 => 0, 0 => 0, 1 => 0}
    @board.transpose.each do |col|
      col.each_cons(2) do |(first, second)|
        first = 1 if first.nil?
        second = 1 if second.nil?

        vertical_count[first <=> second] += (Math.log2(first) - Math.log2(second)).abs
      end
    end

    return horizontal_count.values.reduce(&:-).abs + vertical_count.values.reduce(&:-).abs
  end


  def smoothness
    # First definition of smoothness: number of mergeable tiles in a single move
    # Compact is used before iterating to ignore distance between tiles

    smoothness_row_first = 0
    smoothness_col_first = 0

    considered_row_first = Array.new(@board.size) { Array.new(@board.size) { false } }
    considered_col_first = Array.new(@board.size) { Array.new(@board.size) { false } }

    @board.each_with_index do |row, row_idx|
      row.compact.each_cons(2).with_index do |(first, second), col_idx|
        next if considered_row_first[row_idx][col_idx]

        if first == second
          smoothness_row_first += 1
          considered_row_first[row_idx][col_idx] = true
          considered_row_first[row_idx][col_idx+1] = true
        end
      end
    end
    @board.transpose.each_with_index do |col, col_idx|
      col.compact.each_cons(2).with_index do |(first, second), row_idx|
        next if considered_row_first[row_idx][col_idx] && considered_col_first[row_idx][col_idx]

        if first == second
          unless considered_row_first[row_idx][col_idx]
            smoothness_row_first += 1
            considered_row_first[row_idx][col_idx] = true
            considered_row_first[row_idx+1][col_idx] = true
          end

          unless considered_col_first[row_idx][col_idx]
            smoothness_col_first += 1
            considered_col_first[row_idx][col_idx] = true
            considered_col_first[row_idx+1][col_idx] = true
          end
        end
      end
    end
    @board.each_with_index do |row, row_idx|
      row.compact.each_cons(2).with_index do |(first, second), col_idx|
        next if considered_col_first[row_idx][col_idx]

        if first == second
          smoothness_col_first += 1
          considered_col_first[row_idx][col_idx] = true
          considered_col_first[row_idx][col_idx+1] = true
        end
      end
    end

    [smoothness_row_first, smoothness_col_first].max
  end

  def smoothness2
    # Definition idea from ov3y's 2048-AI

    smoothness = 0

    @board.each do |row|
      row.compact.each_cons(2) do |(first, second)|
        smoothness -= (Math.log2(first) - Math.log2(second)).abs
      end
    end

    @board.transpose.each do |col|
      col.compact.each_cons(2) do |(first, second)|
        smoothness -= (Math.log2(first) - Math.log2(second)).abs
      end
    end

    return smoothness
  end
  
  def clusteredness
    # This indicator sort of takes in account both the emptiness of the board
    # and the maximum value reached: merging two cells causes the clusteredness
    # to increment of two times the sum of the cells' value.
    @board.flatten.compact.map { |elem| elem ** 2 }.reduce(:+)
  end

  def move(direction)
    return self if direction.nil?

    result = traverse_methods(direction)[:direction].bind(@board).call
    result.each do |array|
      merged = Array.new(@board.size) { false }
      traverse_methods(direction)[:iteration].bind(array).call do |value, index|
        next if value.nil?

        prev_index = index - increment(direction)
        next if prev_index >= array.size || prev_index < 0

        while prev_index < array.size && prev_index >= 0 && array[prev_index].nil?
          prev_index -= increment(direction)
        end
        prev_index += increment(direction) if prev_index >= array.size || prev_index < 0

        if value == array[prev_index]
          array[index] = nil
          array[prev_index] += value
          merged[prev_index] = true
        else
          prev_index += increment(direction) unless array[prev_index].nil?

          array[index] = nil
          array[prev_index] = value
        end
      end
    end
    result = traverse_methods(direction)[:direction].bind(result).call
    return Board.new(result)
  end

  def to_s
    result = "-----------------------------\n"
    @board.each do |row|
      row.each do |cell|
        if cell.nil?
          result += "|      "
        else
          result += "| %4d " % cell
        end
      end
      result += "|\n"
    end
    result += "-----------------------------"
  end

  private

  def traverse_methods(direction)
    case direction
    when :up
      {:direction => Array.instance_method(:transpose),
       :iteration => Array.instance_method(:each_with_index)}
    when :left
      {:direction => Array.instance_method(:deep_copy),
       :iteration => Array.instance_method(:each_with_index)}
    when :down
      {:direction => Array.instance_method(:transpose),
       :iteration => Array.instance_method(:reverse_each_with_index)}
    when :right
      {:direction => Array.instance_method(:deep_copy),
       :iteration => Array.instance_method(:reverse_each_with_index)}
    end
  end

  def increment(direction)
    case direction
    when :up, :left
      1
    when :right, :down
      -1
    end
  end
end
