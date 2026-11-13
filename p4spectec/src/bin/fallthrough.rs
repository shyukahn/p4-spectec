//! Fallthrough statistics
//!
//! Converts specification files into PL and counts the `Fallthrough` notes,
//! split by cause: a relation premise (`Rule`) that may not apply,
//! or a function call that may mismatch anywhere else.

use std::{path::PathBuf, process::ExitCode};

use clap::Parser;
use p4spectec::{
    diagnostic::{RenderConfig, Renderer, Report},
    lang::pl::ast::{
        Block, Case, DefKind, DispatchInstr, Fallthrough, GroupInstr, HoldCase, Instr, InstrKind,
        MetaFuncDef, RelDef, Spec,
    },
};

/// Count fallthroughs of P4-SpecTec specifications in PL.
#[derive(Parser)]
#[command(version)]
struct Cli {
    /// Specification files or directories in processing order.
    #[arg(required = true, value_name = "PATH")]
    paths: Vec<PathBuf>,
}

/// Fallthrough counts of a PL specification, by cause.
#[derive(Default)]
struct Counts {
    /// Mismatches of relation premises.
    relation: usize,
    /// Mismatches of function calls.
    function: usize,
}

/// An instruction tier that may nest blocks and call relations.
trait Tier: Sized {
    /// Reports whether the instruction is a relation premise.
    fn is_rel_call(&self) -> bool;
    /// Counts the fallthroughs nested in the instruction.
    fn count(&self, counts: &mut Counts);
}

impl Tier for GroupInstr {
    fn is_rel_call(&self) -> bool {
        matches!(self, GroupInstr::Rule(_))
    }

    fn count(&self, counts: &mut Counts) {
        match self {
            GroupInstr::Backtrack(instr) => instr.blocks.iter().for_each(|b| counts.block(b)),
            GroupInstr::Result(_) | GroupInstr::Return(_) | GroupInstr::Rule(_) => {}
        }
    }
}

impl Tier for DispatchInstr {
    fn is_rel_call(&self) -> bool {
        false
    }

    fn count(&self, counts: &mut Counts) {
        match self {
            DispatchInstr::Group(instr) => counts.block(&instr.block),
            DispatchInstr::Route(instr) => instr.blocks.iter().for_each(|b| counts.block(b)),
        }
    }
}

impl Counts {
    fn of(spec: &Spec) -> Self {
        let mut counts = Self::default();
        for def in spec {
            match &def.node.node {
                DefKind::Rel(RelDef::Defined(rel)) => {
                    counts.block(&rel.block);
                    rel.block_else_opt.iter().for_each(|b| counts.block(b));
                }
                DefKind::MetaFunc(MetaFuncDef::Defined(func)) => {
                    counts.block(&func.block);
                    func.block_else_opt.iter().for_each(|b| counts.block(b));
                }
                DefKind::MetaFunc(MetaFuncDef::Table(table)) => {
                    table.rows.iter().for_each(|row| counts.block(&row.block));
                }
                DefKind::Rel(RelDef::Extern(_))
                | DefKind::MetaFunc(MetaFuncDef::Extern(_) | MetaFuncDef::Builtin(_))
                | DefKind::Typ(_)
                | DefKind::Var(_) => {}
            }
        }
        counts
    }

    fn total(&self) -> usize {
        self.relation + self.function
    }

    /// Counts a fallthrough note by its cause.
    fn note(&mut self, fallthrough: Option<&Fallthrough>, is_rel_call: bool) {
        match (fallthrough, is_rel_call) {
            (None, _) => {}
            (Some(_), true) => self.relation += 1,
            (Some(_), false) => self.function += 1,
        }
    }

    fn block<T: Tier>(&mut self, block: &Block<T>) {
        block.instrs.iter().for_each(|instr| self.instr(instr));
    }

    fn instr<T: Tier>(&mut self, instr: &Instr<T>) {
        let is_rel_call = matches!(&instr.node.node, InstrKind::Tier(t) if t.tier.is_rel_call());
        self.note(instr.node.note.as_ref(), is_rel_call);
        match &instr.node.node {
            InstrKind::If(instr) => self.block(&instr.block),
            InstrKind::IfLetSub(instr) => self.block(&instr.block),
            InstrKind::IfLetMatch(instr) => self.block(&instr.block),
            InstrKind::Check(instr) => self.block(&instr.block),
            InstrKind::Hold(instr) => match &instr.hold_case {
                HoldCase::Both(block_hold, block_not_hold) => {
                    self.block(block_hold);
                    self.block(block_not_hold);
                }
                HoldCase::Hold(block, _) | HoldCase::NotHold(block, _) => self.block(block),
            },
            InstrKind::Case(instr) => instr.cases.iter().for_each(|case| self.case(case)),
            InstrKind::Tier(instr) => instr.tier.count(self),
            InstrKind::Let(_) | InstrKind::Debug(_) | InstrKind::Destruct(_) => {}
        }
    }

    /// Counts a case guard, which mismatches only through a function call.
    fn case<T: Tier>(&mut self, case: &Case<T>) {
        self.note(case.fallthrough.as_ref(), false);
        self.block(&case.block);
    }
}

/// Renders a diagnostic to stderr.
fn render_report(report: &Report) {
    let mut renderer = Renderer::new(RenderConfig::default());
    if let Err(error) = renderer.render_to_stderr(report) {
        eprintln!("{report}\ndiagnostic rendering failed: {error}");
    }
}

fn run(cli: Cli) -> Result<(), ()> {
    let spec = p4spectec::prosify(&cli.paths).map_err(|report| render_report(&report))?;

    let counts = Counts::of(&spec);
    let rows =
        [("relation", counts.relation), ("function", counts.function), ("total", counts.total())];
    for (name, count) in rows {
        println!("{name:<10}{count:>8}");
    }
    Ok(())
}

fn main() -> ExitCode {
    match run(Cli::parse()) {
        Ok(()) => ExitCode::SUCCESS,
        Err(()) => ExitCode::FAILURE,
    }
}
