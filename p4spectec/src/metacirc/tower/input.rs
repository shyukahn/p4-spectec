//! The program above the top level, and the inputs of the native base's entry
//!
//! `Tower::parse_input` reads the program in the language the top level accepts:
//! a P4 program, or an AL script.
//!
//! The meta specification's entry relations, such as spec-meta's `Eval_rel`, take a script,
//! the name of the script's entry, and the entry's inputs as meta values.
//! For `towers/al-p4.json`, the base calls
//! ``Eval_rel: <P4 spec as AL> |- "Program_inst" `( <program as val> `) : val*``.
//! Each level above the base wraps the inputs of the level above it this way,
//! through the protocol of the boundary below it (`Protocol::encode_entry`),
//! with the level encoded in the language of the level consuming it.
//! A program above the top is one more level: an AL script is entered
//! at the configured entry with no inputs, its function `main` through
//! `Eval_func` or `Eval_AL_func`, or a relation through `Eval_rel` or `Eval_AL_rel`.

use super::super::{Result, config::Lang, error};
use super::{Input, Script, Tower};
use crate::{
    interface::p4::parse::parse_file,
    lang::data::{arena::Arena, value::flat::Value},
    runner::Extern,
};
use std::path::PathBuf;

// == Tower input

impl<Ext: Extern> Tower<Ext> {
    /// Reads the program at `paths` in the language the top level accepts.
    pub fn parse_input(
        &self,
        arena: &mut Arena,
        includes: &[PathBuf],
        paths: &[PathBuf],
    ) -> Result<Input> {
        if paths.is_empty() {
            return Err(error::input_invalid("a tower requires at least one program path"));
        }
        match self.lang_top() {
            Lang::Al => Ok(Input::Script(Script::Al(crate::algo(paths)?))),
            // P4 inputs contain exactly one translation unit
            Lang::P4 => {
                let [path] = paths else {
                    return Err(error::input_invalid(
                        "a P4 top level requires exactly one program path",
                    ));
                };
                let program = parse_file(arena, includes, path).map_err(|e| e.into_report())?;
                Ok(Input::P4(program))
            }
        }
    }

    /// Encodes an input as the inputs of the native base's entry relation.
    ///
    /// Encoding errors remain separate from the subsequent evaluation.
    pub fn encode_input(&self, arena: &mut Arena, input: &Input) -> Result<Vec<Value>> {
        let lang_top = self.lang_top();
        // A P4 program is the top level's input; a script is a program above the top
        let (mut values, program) = match (input, lang_top) {
            (Input::P4(program), Lang::P4) => (vec![*program], None),
            (Input::Script(script @ Script::Al(_)), Lang::Al) => {
                (vec![], Some((script.entered(), self.entry.as_str())))
            }
            _ => {
                let message = format!("the top level accepts {lang_top:?}, not this input");
                return Err(error::input_invalid(message));
            }
        };
        // Each level above the base, and a program above the top,
        // is entered through the protocol of the boundary below it
        let entries = self.levels[1..]
            .iter()
            .map(|level| (level.entered(), level.config().rel.as_str()))
            .chain(program)
            .collect::<Vec<_>>();
        let protocols = self.base.upper().map_or(&[][..], |upper| &upper.protocols);
        for ((above, name), protocol) in entries.into_iter().zip(protocols).rev() {
            values = protocol.encode_entry(arena, above, name, &values)?;
        }
        Ok(values)
    }

    /// Returns the language the top level accepts.
    fn lang_top(&self) -> Lang {
        self.levels
            .last()
            .expect("validated nonempty tower")
            .config()
            .lang
    }
}
