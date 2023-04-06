#!/usr/bin/env python3
# coding=utf8

from argparse import ArgumentParser, FileType, ArgumentTypeError
from re import split
from sexpdata import loads
from os.path import dirname
from jinja2 import FileSystemLoader, Environment


def parse_arguments():
    def comma_separated_list(argument):
        return argument.split(",")

    parser = ArgumentParser(description="Convert KiCad net list to c header", epilog="")

    parser.add_argument(
        "-n",
        "--net",
        required=True,
        type=FileType("r"),
        help="path to net list input file",
    )
    parser.add_argument(
        "-p",
        "--part",
        required=True,
        type=str,
        help="Part number of component of interest",
    )
    parser.add_argument(
        "-c",
        "--connections",
        default="LED,BUTTON,TX,RX",
        type=comma_separated_list,
        help="comma separated list of net names of interest",
    )
    parser.add_argument(
        "-o",
        "--output",
        required=True,
        type=FileType("w"),
        help="path to c header output file",
    )
    parser.add_argument(
        "-g",
        "--guard",
        default="BOARD_CONFIG_H",
        type=str,
        help="c header guard string",
    )

    args = parser.parse_args()
    return args


def sexp_to_set(sexp):
    return {sub_sexp[0].value(): sub_sexp for sub_sexp in sexp}


def main():
    args = parse_arguments()

    net_list_sexp = loads(args.net.read())
    args.net.close()

    params = {"mcu": args.part, "guard": args.guard, "connections": []}

    net_list_sexp_set = sexp_to_set(net_list_sexp[1:])

    # get title
    textvars = {
        design_sexp[1][1]: design_sexp[2]
        for design_sexp in net_list_sexp_set["design"][1:]
        if "textvar" == design_sexp[0].value()
    }
    params["board"] = textvars["title"]

    # search for component
    ref = None
    for component_sexp in net_list_sexp_set["components"][1:]:
        component_sexp_set = sexp_to_set(component_sexp[1:])
        value = component_sexp_set["value"][1]
        if args.part == value:
            ref = component_sexp_set["ref"][1]
            break

    if not ref:
        print(f"{args.part} not in net list")
        return -1

    # look up nets connected to component
    for net_sexp in net_list_sexp_set["nets"][1:]:
        node_sexp_list = [
            sub_sexp for sub_sexp in net_sexp[1:] if "node" == sub_sexp[0].value()
        ]
        node_sexp_set_list = [
            sexp_to_set(node_sexp[1:]) for node_sexp in node_sexp_list
        ]
        ref_pinfunction_map = {
            node_sexp_set["ref"][1]: node_sexp_set["pinfunction"][1]
            for node_sexp_set in node_sexp_set_list
            if "pinfunction" in node_sexp_set
        }
        if ref in ref_pinfunction_map:
            # remove hostile characters from net name
            net_name = sexp_to_set(net_sexp[1:])["name"][1]
            pinfunction = ref_pinfunction_map[ref].split("/")[0]

            net_name = split("/|\\.", net_name)[-1]
            pinfunction = split("/", pinfunction)[0]

            for name in args.connections:
                if name in net_name:
                    params["connections"] += [{"net": net_name, "pin": pinfunction}]

    templateEnv = Environment(loader=FileSystemLoader(searchpath=dirname(__file__)))
    template = templateEnv.get_template("board_config.h.j2")
    outputText = template.render(**params)

    args.output.write(outputText)
    args.output.close()

    return 0


if "__main__" == __name__:
    exit(main())
