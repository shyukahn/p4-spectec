//! The St backend: specifications written in P4-SpecTec, run natively
//!
//! `EngineSt` executes the base on the AL or SL interpreter.
//! `ProtocolStSt` is spec-meta's protocol, interpreting the level above as AL;
//! `ProtocolStStExt` is spec-meta-ext's, interpreting it as AL or IL.

mod engine;
mod protocol_st;
mod protocol_st_ext;

pub(super) use engine::{EngineSt, SpecSt, StateSt};
pub(super) use protocol_st::ProtocolStSt;
pub(super) use protocol_st_ext::ProtocolStStExt;
