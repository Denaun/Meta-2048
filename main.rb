#!/usr/bin/env ruby

require 'rubygems'
require 'selenium-webdriver'

require_relative 'board'
require_relative 'boardSolver'

def read_board(driver)
  result = Board.new(SIZE)
  board = driver.find_elements(:class, "tile")
  board.each do |cell|
    position = /tile-(?<val>\d+) tile-position-(?<col>\d+)-(?<row>\d+)/.match(cell.attribute(:class))
    
    row = position[:row].to_i - 1
    col = position[:col].to_i - 1
    val = position[:val].to_i
    result[row, col] = val
  end
  return result
end

file = File.open("key.js", "r")
KEY_PRESS_SCRIPT = file.read
file.close

SIZE = 4 # TODO Get it
KEY_UP = 38
KEY_LEFT = 37
KEY_DOWN = 40
KEY_RIGHT = 39

driver = Selenium::WebDriver.for :safari
driver.get "http://gabrielecirulli.github.io/2048/"
# driver.get "http://games.usvsth3m.com/2048/degrado-edition/"

key = 37
previous = Board.new(SIZE)
loop do
  begin
    driver.find_element(:class, "game-over").nil?
    puts "Fail."
    break
  rescue Selenium::WebDriver::Error::NoSuchElementError
  end

  begin
    driver.find_element(:class, "game-won").nil?
    puts "*** Won! ***"
    driver.find_element(:class, "keep-playing-button").click
  rescue Selenium::WebDriver::Error::NoSuchElementError
  end

  puts "New iteration"

  current = read_board(driver)

  puts current
  puts "Empty cells: #{current.empty_count}"
  puts "Monotonicity: #{current.monotonicity}"
  puts "Monotonicity2: #{current.monotonicity2}"
  puts "Smoothness: #{current.smoothness}"
  puts "Smoothness2: #{current.smoothness2}"
  puts "Clusteredness: #{current.clusteredness}"

  best_direction = BoardSolver.new(current).timed_improvement(0.1) do |board|
    board.clusteredness
  end
  puts "Chosen action: #{best_direction}."

  key = 
    case best_direction
    when nil then 37 + (key%4)
    when :up then KEY_UP
    when :left then KEY_LEFT
    when :down then KEY_DOWN
    when :right then KEY_RIGHT
    end

  previous = current
  driver.execute_script(KEY_PRESS_SCRIPT, key)

  sleep(0.075)
end

final = read_board(driver)
puts final
puts "Max: #{final.max}"
puts "Points: #{driver.find_element(:class, "score-container").text[/\d+/]}"

puts "Press ENTER to quit."
STDIN.gets

driver.quit
