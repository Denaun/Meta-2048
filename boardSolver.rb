require_relative 'board'

class BoardSolver
  DIRECTIONS = [:up, :left, :down, :right]
  TURN = [:player, :computer]

  def initialize(board, turn=:player)
    @board = board
    @turn = turn
  end

  def player_turn?
    @turn == :player
  end

  def maximise_heuristic(heuristic, board, directions=[nil, :up, :left, :down, :right])
    return directions if directions.size == 1

    result = []
    best_value = -Float::INFINITY

    directions.compact.each do |direction|
      new_situation = board.move(direction)
      next if board == new_situation

      new_value = new_situation.method(heuristic).call
      if new_value > best_value
        result = [direction]
        best_value = new_value
      elsif new_value == best_value
        result = result << direction
      end
    end

    if directions.include? nil
      current_value = board.method(heuristic).call
      if current_value > best_value
        directions
      elsif current_value == best_value
        result << nil
      else
        result
      end
    else
      result
    end
  end

  def dfs(max_depth, &heuristic)
    return [nil, yield(@board)] if max_depth == 0

    results = {}
    DIRECTIONS.each do |direction|
      new_board = @board.move(direction)
      next if new_board == @board

      results[direction] = BoardSolver.new(new_board).dfs(max_depth-1, &heuristic)[1]
    end

    results.max_by{ |k, v| v }
  end

  def minmax(max_depth, alpha, beta, &player_heuristic)
    if self.player_turn?
      return [nil, yield(@board)] if max_depth == 0
      return [nil, -Float::INFINITY] if @board.empty_count == 0 && @board.smoothness == 0

      best_result = [nil, alpha]

      DIRECTIONS.each do |direction|
        new_board = @board.move(direction)
        next if new_board == @board

        result = [direction,
                  BoardSolver.new(new_board, :computer)
                    .minmax(max_depth-1, best_result[1], beta, &player_heuristic)[1]]

        if result[1] > best_result[1]
          if result[1] > beta
            return [direction, beta]
          end

          best_result = result
        end
      end

      return best_result
    else
      moves = {}
      [2, 4].each do |value|
        @board.size.times do |row|
          @board.size.times do |col|
            next unless @board[row, col].nil?

            @board[row, col] = value
            (moves[computer_heuristic] ||= []) << [row, col, value]
            @board[row, col] = nil
            # (moves[0] ||= []) << [row, col, value]
          end
        end
      end
      candidates = moves[moves.keys.max]

      best_result = beta
      candidates.each do |(row, col, value)|
        (new_board = @board.deep_copy)[row, col] = value

        result = BoardSolver.new(new_board, :player)
          .minmax(max_depth, alpha, best_result, &player_heuristic)[1]

        if result < best_result
          if result < alpha
            return [nil, alpha]
          end

          best_result = result
        end
      end

      return [nil, best_result]
    end
  end

  def nearest_improvement(max_depth, &heuristic)
    threshold = yield(@board)
    best_non_improvement = [nil, -Float::INFINITY]

    (1..max_depth).each do |depth|
      result = dfs(depth, &heuristic)

      if result[1] > threshold
        return result[0]
      elsif result[1] > best_non_improvement[1]
        best_non_improvement = result
      end
    end

    puts "No improvement found!"

    return best_non_improvement[0]
  end

  def timed_improvement(min_time_s, &heuristic)
    best_improvement = [nil, -Float::INFINITY]

    time_start = Time.now.to_f
    1.upto(Float::INFINITY) do |depth|
      break unless Time.now.to_f - time_start < min_time_s

      puts "Depth: #{depth}."

      result = minmax(depth, -Float::INFINITY, Float::INFINITY, &heuristic)

      if result[1] == -Float::INFINITY
        return nil
      end
        best_improvement = result
    end 

    puts "Took #{Time.now.to_f - time_start - min_time_s} extra seconds..!"

    return best_improvement[0]
  end

  def computer_heuristic
    -@board.smoothness2
  end
end
