"""
Filters, summarizes, and plots BLAST output using matplotlib and
computes cumulative-sum table for alignment scores
"""

import argparse
from math import log10
import os
import shutil
from uuid import uuid4

import numpy as np

from plot import draw_boxplot, draw_histogram
from cachemanager import CacheManager, Group

def parse_args():
    parser = argparse.ArgumentParser(description="Render plots from BLAST output")
    parser.add_argument("--blast-output", type=str, required=True, help="7-column output file from BLAST")
    parser.add_argument("--job-id", required=True, help="Job ID number for BLAST output file")
    parser.add_argument("--min-edges", 
                        type=int, default=10, 
                        help="Minimum number of edges needed to retain an alignment-score group")
    parser.add_argument("--min-groups", 
                        type=int, default=30, 
                        help="Minimum number of alignment-score groups to retain in output")
    parser.add_argument("--length-plot-filename", type=str, required=True, help="Filename, without extention, to write the alignment length boxplots to")
    parser.add_argument("--pident-plot-filename", type=str, required=True, help="Filename, without extention, to write the percent identity boxplots to")
    parser.add_argument("--edge-hist-filename", type=str, required=True, help="Filename, without extention, to write the edge count histograms to")
    parser.add_argument("--output-type", type=str, default="png", choices=["png", "svg", "pdf"])
    
    args = parser.parse_args()
    return args

def group_output_data(blast_output: str) -> tuple[dict[int, Group], str]:
    """
    Compute alignment score and use it to bin rows from BLAST output

    Also saves edge counts to `evalue.tab`.

    Parameters:
    ---
        blast_output (str) - Path to the BLAST output file

    Returns:
    ---
        dictionary of alignment scores as keys and CacheManager.Group values
        string name of directory used for cache (so it can be deleted later)
    """
    log10of2 = log10(2)
    with open(blast_output) as f:
        cachedir = f"./data_{str(uuid4()).split('-')[0]}"
        with CacheManager(cachedir) as cm:
            for line in f:
                fields = line.strip().split("\t")
                percent_identical = fields[2]
                alignment_length = fields[3]
                fields[3:] = list(map(float, fields[3:]))
                alignment_score = int(-(log10(fields[5] * fields[6])) + fields[4] * log10of2)

                cm.append(alignment_score, alignment_length, percent_identical)

            cm.save_edge_counts("evalue.tab")
            metadata = cm.get_edge_counts_and_filenames()
    
    return metadata, cachedir

def compute_outlying_groups(group_metadata: dict[int, Group], min_num_edges: int, min_num_groups: int) -> set:
    """
    Determine groups to exclude from plots

    Considers groups in sorted order and locates the first and last group which has less than
    `min_num_edges`. Cuts groups that are less than the first or greater than the last group. Some
    groups between these endpoints may still have less than `min_num_edges`. If the the number of
    groups present after removing the outliers is less than `min_group_size`, the upper cutoff 
    index is incremented until the group size meets the minimum or no more groups are left to
    include.

    Parameters:
    ---
        group_metadata (dict[int, Group]) - cache metadata from `group_output_data`
        
        min_num_edges (int) - minimum number of edges needed to retain a group
        
        min_num_groups (int) - keep at least this many groups (may override min_num_edges)

    Returns:
    ---
        A set of groups to exclude
    """
    sizes = [(k, group_metadata[k].edge_count) for k in sorted(group_metadata.keys())]
    
    lower_bound_idx = 0
    upper_bound_idx = 0
    # find first group with at least min_num_edges edges
    for i, t in enumerate(sorted(sizes)):
        if t[1] >= min_num_edges:
            lower_bound_idx = i
            break

    # find last group with at least min_num_edges edges
    for i, t in enumerate(reversed(sizes)):
        if t[1] >= min_num_edges:
            upper_bound_idx = i
            break

    # ensure we have at least min_num_groups, walk upper index forward if not
    while upper_bound_idx < len(sizes) and upper_bound_idx - lower_bound_idx + 1 < min_num_groups:
        upper_bound_idx += 1
    # extract `alignment_score`s from sizes array, put in Set of O(1) lookups in subsequent filter
    groups_to_keep = set(k for k, _ in sizes[lower_bound_idx:-upper_bound_idx])

    return set([k for k, _ in sizes]) - groups_to_keep

def compute_summary_statistic_for_group(filename: str) -> dict[str, float]:
    """
    Compute five-number summary for a given cache file

    Cache files (written by CacheManager) are a list of ints, one per line, that describe
    either all of the alignment lengths or percent identicals for a given alignment score. To
    render a boxplot, only the min, max, median, and quartiles are needed (five number summary, 
    https://en.wikipedia.org/wiki/Five-number_summary). This function returns those values in a 
    dict than can be passed to matplotlib's [bxp function]
    (https://matplotlib.org/stable/api/_as_gen/matplotlib.axes.Axes.bxp.html)

    Parameters:
    ---
        filename (str) - path to a file written by CacheManager, 1 value per line
    
    Returns:
    ---
        A 5-key dictionary that contains a five-number summary of the input file
    """
    group_data = np.loadtxt(filename, dtype=np.float32)
    fivenum = np.quantile(group_data, [0, .25, .5, .75, 1])
    bxp_summary =  {"whislo": fivenum[0], "q1": fivenum[1], "med": fivenum[2], "q3": fivenum[3], "whishi": fivenum[4]}
    return bxp_summary

def compute_summary_statistics(metadata: dict[int, Group], field: str) -> tuple[list[dict[str, float]], list[int]]:
    """
    Computes five-number summaries for the indicated field, either "length_filename" or "pident_filename"

    Parameters:
    ---
        metadata (dict[int, Group]) - cache metadata from `group_output_data`
        
        field (str) - either "length_filename" or "pident_filename"

    Returns:
    ---
        A list of dictionaries that can be passed to matplotlib's bxp function and a list
        of integers to be used as x-axis positions
    """
    summary = []
    xpos = sorted(list(metadata.keys()))
    for group in xpos:
        fname = metadata[group]._asdict()[field]
        summary.append(compute_summary_statistic_for_group(fname))
    return summary, xpos

def delete_outlying_groups(metadata: dict[int, Group], groups_to_delete: set) -> dict[int, Group]:
    """
    Removes outlying groups from metadata

    Parameters:
    ---
        metadata (dict[int, Group]) - cache metadata from `group_output_data`
        
        groups_to_delete (set) - set of groups to exclude from the returned dict

    Returns:
    ---
        Metadata dict with groups removed
    """
    for group in groups_to_delete:
        os.remove(metadata[group].length_filename)
        os.remove(metadata[group].pident_filename)
        del metadata[group]
    return metadata

def get_edge_hist_data(metadata: dict[int, Group]) -> tuple[list[int], list[int]]:
    """
    Extracts alignment_score and edge_count from metadata

    Parameters:
    ---
        metadata (dict[int, Group]) - cache metadata from `group_output_data`

    Returns:
    ---
        list of ints to use as x-axis positions and list of ints representing heights of bars
    """
    xpos = sorted(list(metadata.keys()))
    heights = [metadata[k].edge_count for k in xpos]
    return xpos, heights

def main(blast_output, job_id, min_edges, min_groups, length_filename, pident_filename, edge_filename, output_format, delete_cache=True):
    # compute groups and trim outliers
    print("grouping output data")
    metadata, cachedir = group_output_data(blast_output)

    print("computing groups to discard")
    groups_to_delete = compute_outlying_groups(metadata, min_edges, min_groups)

    print(f"deleting {len(groups_to_delete)} groups")
    metadata = delete_outlying_groups(metadata, groups_to_delete)

    # plot alignment_length
    print("Computing boxplot stats for alignment length")
    length_dd, length_xpos = compute_summary_statistics(metadata, "length_filename")
    draw_boxplot(length_dd, length_xpos, f"Alignment Length vs Alignment Score for Job {job_id}",
                "Alignment Score", "Alignment Length", length_filename, output_format)

    # percent identical box plot data
    print("Computing boxplot stats for percent identical")
    pident_dd, pident_xpos = compute_summary_statistics(metadata, "pident_filename")
    draw_boxplot(pident_dd, pident_xpos, f"Percent Identical vs Alignment Score for Job {job_id}",
                "Alignment Score", "Percent Identical", pident_filename, output_format)
    
    # draw edge length histogram
    print("Extracting histogram data")
    xpos, heights = get_edge_hist_data(metadata)
    draw_histogram(xpos, heights, f"Number of Edges at Alignment Score for Job {job_id}",
                "Alignment Score", "Number of Edges", edge_filename, output_format)

    # cleanup cache dir
    if delete_cache:
        shutil.rmtree(cachedir)

if __name__ == "__main__":
    args = parse_args()
    main(args.blast_output, args.job_id, args.min_edges, args.min_groups,
         args.length_plot_filename, args.pident_plot_filename, args.edge_hist_filename, args.output_type)