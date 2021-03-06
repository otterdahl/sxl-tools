#!/usr/bin/env ruby
require 'yaml'
require 'rubyXL'
require 'rubyXL/convenience_methods'
require 'optparse'

# yaml2xlsx reads sxl in yaml-format and outputs to xlsx-format

# Excel template defaults
@return_value_no=2
@return_value_start_col=4

def set_cell(sheet, col, row, string)
  return if string == nil
  col -= 1
  row -= 1
  if sheet[row] == nil or sheet[row][col] == nil
    sheet.add_cell row, col, string
  else
    sheet[row][col].change_contents string
  end
end

def insert_return_value(sheet)
  start_col = @return_value_start_col + (@return_value_no*4)
  end_col=start_col+3
  @return_value_no += 1

  # border lines
  for c in start_col..end_col
    for r in 4..15
      sheet.insert_cell(r, c, "", formula = nil, :right)
      cell = sheet[r][c]
      cell.change_border(:bottom, 'thin') if r < end_col
      cell.change_border(:right, 'thin') if c < end_col
      cell.change_border(:top, 'medium') if r == 4
      cell.change_border(:right, 'medium') if c == end_col
      cell.change_border(:bottom, 'medium') if r == end_col or r == 5
    end
  end
  
  # title: return value
  cell = sheet[4][start_col]
  cell.change_contents("return value", formula = nil)
  cell.change_horizontal_alignment('center')
  cell.change_font_italics(true)
  cell.change_font_bold(true)
  sheet.merge_cells(4, start_col, 4, end_col)
  
  # title
  sheet[5][start_col].change_contents("Name", formula = nil)
  sheet[5][start_col+1].change_contents("Type", formula = nil)
  sheet[5][start_col+2].change_contents("Value", formula = nil)
  sheet[5][start_col+3].change_contents("Comment", formula = nil)

end

options = {}
usage = "Usage: yaml2xlsx.rb [--template <XLSX>]"
OptionParser.new do |opts|
  opts.banner = usage

  opts.on("--template [XLSX]", "SXL Template") do |p|
    options[:template] = p
  end

  opts.on("--short-desc", "Short description") do |s|
    options[:short] = s
  end

  opts.on("--stdout", "Output xlsx on STDOUT") do |o|
    options[:stdout] = o
  end
end.parse!

abort("--template needs to be set") if options[:template].nil?


workbook = RubyXL::Parser.parse(options[:template])

# Read yaml from stdin
input = ARGF.read()
sxl = YAML.load(input)

# Version
sheet = workbook['Version']
set_cell(sheet, 2, 4, sxl["id"])            # Plant id
set_cell(sheet, 2, 6, sxl["description"])   # Plant name
set_cell(sheet, 2, 10, sxl["constructor"])  # Constructor
set_cell(sheet, 2, 12, sxl["reviewed"])     # Reviewed
set_cell(sheet, 2, 15, sxl["approved"])     # Approved
set_cell(sheet, 2, 18, sxl["created-date"]) # Created date
set_cell(sheet, 2, 21, sxl["version"])      # SXL revision number
set_cell(sheet, 3, 21, sxl["date"])         # SXL revision date
set_cell(sheet, 2, 26, sxl["rsmp-version"]) # RSMP version

# Object types
sheet = workbook['Object types']
gy = 7  # grouped object type, y pos
sy = 19 # single object type, y pos
sxl["objects"].each { |object|
  # Is it a grouped object or not
  unless object[1]["aggregated_status"].nil?
    set_cell(sheet, 1, gy, object[0])
    set_cell(sheet, 2, gy, object[1]["description"])
    gy = gy + 1
  else
    set_cell(sheet, 1, sy, object[0])
    set_cell(sheet, 2, sy, object[1]["description"])
    sy = sy + 1
  end
}

# Objects
sheet = workbook['Objects']
gy = 7  # grouped object type, y pos
sy = 25 # single object type, y pos
sxl["sites"].each { |site|
  set_cell(sheet, 2, 2, site[0])
  set_cell(sheet, 3, 2, site[1]["description"])

  sxl["objects"].each { |object|
    # Is it a grouped object or not
    unless object[1]["aggregated_status"].nil?

      site[1]["objects"][object[0]].each { |grouped|
        set_cell(sheet, 1, gy, object[0])
        set_cell(sheet, 2, gy, grouped[0])
        set_cell(sheet, 3, gy, grouped[1]["componentId"])
        set_cell(sheet, 4, gy, grouped[1]["ntsObjectId"])
        set_cell(sheet, 5, gy, grouped[1]["externalNtsId"])
        set_cell(sheet, 6, gy, grouped[1]["description"])
        gy = gy + 1
      }
    else
      site[1]["objects"][object[0]].each { |single|
        set_cell(sheet, 1, sy, object[0])
        set_cell(sheet, 2, sy, single[0])
        set_cell(sheet, 3, sy, single[1]["componentId"])
        set_cell(sheet, 4, sy, single[1]["ntsObjectId"])
        set_cell(sheet, 5, sy, single[1]["externalNtsId"])
        set_cell(sheet, 6, sy, single[1]["description"])
        sy = sy + 1
      }
    end
  }
}

# Aggregated status
sheet = workbook['Aggregated status']
y = 7
sxl["objects"].each { |object|
  unless object[1]["aggregated_status"].nil?
    set_cell(sheet, 1, y, object[0])
    set_cell(sheet, 3, y, object[1]["functional_position"])
    set_cell(sheet, 4, y, object[1]["functional_state"])
    set_cell(sheet, 3, 17, object[1]["aggregated_status"][1]["description"])
    set_cell(sheet, 3, 18, object[1]["aggregated_status"][2]["description"])
    set_cell(sheet, 3, 19, object[1]["aggregated_status"][3]["description"])
    set_cell(sheet, 3, 20, object[1]["aggregated_status"][4]["description"])
    set_cell(sheet, 3, 21, object[1]["aggregated_status"][5]["description"])
    set_cell(sheet, 3, 22, object[1]["aggregated_status"][6]["description"])
    set_cell(sheet, 3, 23, object[1]["aggregated_status"][7]["description"])
    set_cell(sheet, 3, 24, object[1]["aggregated_status"][8]["description"])
  end
}

# Alarm
sheet = workbook['Alarms']
row = 7

# for each object type in yaml, look at all the alarms
sxl["objects"].each { |object|
  object[1]["alarms"].each { |item|
    set_cell(sheet, 1, row, object[0])              # object type
    set_cell(sheet, 2, row, item[1]["object"])      # object
    set_cell(sheet, 3, row, item[0])                # alarmCodeId
    if options[:short].nil?
      set_cell(sheet, 4, row, item[1]["description"])
    else
      set_cell(sheet, 4, row, item[1]["description"].lines.first.chomp)
    end
    set_cell(sheet, 5, row, item[1]["externalAlarmCodeId"])
    set_cell(sheet, 6, row, item[1]["externalNtsAlarmCodeId"])
    set_cell(sheet, 7, row, item[1]["priority"])
    set_cell(sheet, 8, row, item[1]["category"])

    # Return values
    col = 9
    unless item[1]["arguments"].nil?
      item[1]["arguments"].each { |argument, value|
        set_cell(sheet, col, row, argument)
        set_cell(sheet, col+1, row, value["type"])
        if value["type"] == "boolean"
            values = "-False\n-True"
            set_cell(sheet, col+2, row, values)
        else
          unless value["range"].nil?
            set_cell(sheet, col+2, row, value["range"])
          else
            # Make a list of values and append to description
            values = ""
            description = ""
            value["values"].each { |v, desc |
              values += "-" + v + "\n"
              unless desc.empty?
                description += + v + ": " + desc + "\n"
              end
            }
            values.chomp!
            description.chomp!
            if value["description"].nil?
              value["description"] = description
            else
              value["description"].concat("\n" + description)
              value["description"].chomp!
            end
            set_cell(sheet, col+2, row, values)
          end
        end
        set_cell(sheet, col+3, row, value["description"])
        col += 4
      }
    end

    row += 1
  }
}

# Status
sheet = workbook['Status']
row = 7
insert_return_value(sheet)
insert_return_value(sheet)

# for each object type in yaml, look at all the statuses
sxl["objects"].each { |object|
  object[1]["statuses"].each { |item|
    set_cell(sheet, 1, row, object[0])         # object type
    set_cell(sheet, 2, row, item[1]["object"]) # object
    set_cell(sheet, 3, row, item[0])
    if options[:short].nil?
      set_cell(sheet, 4, row, item[1]["description"])
    else
      set_cell(sheet, 4, row, item[1]["description"].lines.first.chomp)
    end

    # Return values
    col = 5
    item[1]["arguments"].each { |argument, value|  # in statuses, it's called return value
      set_cell(sheet, col, row, argument)
      set_cell(sheet, col+1, row, value["type"])
      if value["type"] == "boolean"
          values = "-False\n-True"
          set_cell(sheet, col+2, row, values)
      else
        unless value["range"].nil?
          set_cell(sheet, col+2, row, value["range"])
        else
          # Make a list of values and append to description
          values = ""
          description = ""
          value["values"].each { |v, desc |
            values += "-" + v.to_s + "\n"
            unless desc.empty?
              description += + v.to_s + ": " + desc + "\n"
            end
          }
          values.chomp!
          description.chomp!
          if value["description"].nil?
            value["description"] = description
          else
            value["description"].concat("\n" + description)
          end
          set_cell(sheet, col+2, row, values)
        end
      end
      set_cell(sheet, col+3, row, value["description"])
      col += 4
    }
    row += 1
  }
}

# Commands
sheet = workbook['Commands']
row = 25

# for each object type in yaml, look at all the commands
sxl["objects"].each { |object|
  object[1]["commands"].each { |item|
    set_cell(sheet, 1, row, object[0])           # object type
    set_cell(sheet, 2, row, item[1]["object"])   # object
    set_cell(sheet, 3, row, item[0])
    if options[:short].nil?
      set_cell(sheet, 4, row, item[1]["description"])
    else
      set_cell(sheet, 4, row, item[1]["description"].lines.first.chomp)
    end
 
    # Arguments
    col = 5
    item[1]["arguments"].each { |argument, value|
      set_cell(sheet, col, row, argument)
      set_cell(sheet, col+1, row, item[1]["command"])
      set_cell(sheet, col+2, row, value["type"])
      if value["type"] == "boolean"
          values = "-False\n-True"
          set_cell(sheet, col+3, row, values)
      else
        unless value["range"].nil?
          set_cell(sheet, col+3, row, value["range"])
        else
          # Make a list of values and append to description
          values = ""
          description = ""
          value["values"].each { |v, desc |
            values += "-" + v + "\n"
            unless desc.empty?
              description += + v + ": " + desc + "\n"
            end
          }
          values.chomp!
          description.chomp!
          if value["description"].nil?
            value["description"] = description
          else
            value["description"].concat("\n" + description)
          end
          set_cell(sheet, col+3, row, values)
        end
      end
      set_cell(sheet, col+4, row, value["description"])
      col += 5
    }
    row += 1
  }
}

# Save
if options[:stdout].nil?
  workbook.write("output.xlsx")
else
  # write to stdout instead
  print workbook.stream.string
end
