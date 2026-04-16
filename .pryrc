# frozen_string_literal: true

# Loaded automatically by `rake console` (pry).
# Auto-formats Sequel model arrays as readable tables via table_print.
# Dev-only convenience; has no effect on the app or tests.

require 'table_print'

# Per-model default columns, so `tp FinanceTracker::Transaction.all` and bare
# `FinanceTracker::Transaction.all` both show sensible, non-overflowing output.
if defined?(FinanceTracker::Transaction)
  tp.set FinanceTracker::Transaction, :id, :title, :amount, :date
  tp.set FinanceTracker::Account,     :id, :transaction_id, :name, :amount, :description
  tp.set FinanceTracker::Category,    :id, :transaction_id, :account_id, :name, :description
end

# Make `FinanceTracker::Transaction.all` (and other model arrays) auto-render as tables
# in pry, the way Hirb used to. Falls back to the default printer for
# everything else.
#
# NOTE: TablePrint::Printer.table_print returns a STRING and does not
# write to stdout itself — only the top-level `tp` helper puts it.
# Inside a Pry.config.print hook we have to write to `output` ourselves.
old_print = Pry.config.print
Pry.config.print = proc do |output, value, *rest|
  if value.is_a?(Array) && value.first.is_a?(Sequel::Model)
    output.puts TablePrint::Printer.table_print(value)
  else
    old_print.call(output, value, *rest)
  end
end

puts 'table_print enabled - Sequel model arrays auto-render as tables.'
