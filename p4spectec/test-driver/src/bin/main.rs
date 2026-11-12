use std::{path::PathBuf, process::ExitCode, time::Duration};

use clap::{Parser, Subcommand};

use p4spectec_test::{
    harness::{self, Result},
    suite::{micro, p4parse, run, sim},
};

/// Source and expected-file acceptance for the Rust implementation
#[derive(Parser)]
struct Cli {
    /// Write a per-test timing log of p4parse, run, sim, or micro into a new file in this directory
    #[arg(long = "log", global = true, value_name = "DIR")]
    path_log: Option<PathBuf>,
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// List every registration
    List,
    /// Compare P4 parse/unparse/parse roundtrips with stored file results
    P4parse,
    /// Compare execution outcomes with stored file results
    Run {
        /// Configuration name in `suites/run.toml`
        config: String,
        /// Record a program still running after this many seconds as a timeout.
        #[arg(long, value_name = "SECONDS")]
        timeout: Option<u64>,
    },
    /// Compare simulation outcomes
    Sim {
        /// Configuration name in `suites/sim.toml`
        config: String,
        /// Record a test still running after this many seconds as a timeout.
        #[arg(long, value_name = "SECONDS")]
        timeout: Option<u64>,
    },
    /// Run micro tests: standalone spec-language sources by pipeline stage
    Micro {
        /// Configuration name in `suites/micro.toml`
        config: String,
    },
    /// Run tests one at a time for a driver given `--timeout`
    #[command(hide = true, subcommand)]
    Worker(Worker),
}

/// Prepares a configuration once and answers requests on stdin.
#[derive(Subcommand)]
enum Worker {
    /// Run P4 programs of `suites/run.toml`
    Run { config: String },
    /// Run STF tests of `suites/sim.toml` on one architecture
    Sim { config: String, arch: String },
}

fn execute(cli: Cli) -> Result<()> {
    // Resolve the log path before changing to the specification repository
    let path_log = cli
        .path_log
        .as_deref()
        .map(std::path::absolute)
        .transpose()?;
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../..")
        .canonicalize()?;
    std::env::set_current_dir(&root)?;
    match &cli.command {
        Command::List => list(),
        Command::P4parse => p4parse::run(path_log.as_deref()),
        Command::Run { config, timeout } => {
            run::run(config, timeout.map(Duration::from_secs), path_log.as_deref())
        }
        Command::Sim { config, timeout } => {
            sim::run(config, timeout.map(Duration::from_secs), path_log.as_deref())
        }
        Command::Micro { config } => micro::run(config, path_log.as_deref()),
        Command::Worker(Worker::Run { config }) => run::serve(config),
        Command::Worker(Worker::Sim { config, arch }) => sim::serve(config, arch),
    }
}

/// Prints every registration without running its tests.
fn list() -> Result<()> {
    println!("p4parse: {:#?}", harness::load::<p4parse::Registration>("p4parse")?);
    println!("run: {:#?}", harness::load::<run::Registration>("run")?);
    println!("sim: {:#?}", harness::load::<sim::Registration>("sim")?);
    println!("micro: {:#?}", harness::load::<micro::Registration>("micro")?);
    Ok(())
}

fn main() -> ExitCode {
    let cli = Cli::parse();
    let result = std::thread::Builder::new()
        .name("expected-driver".to_owned())
        .stack_size(64 * 1024 * 1024)
        .spawn(move || execute(cli).map_err(|error| error.to_string()));
    match result {
        Ok(thread) => match thread.join() {
            Ok(Ok(())) => ExitCode::SUCCESS,
            Ok(Err(error)) => {
                eprintln!("{error}");
                ExitCode::FAILURE
            }
            Err(_) => {
                eprintln!("test driver panicked; expected validation failed");
                ExitCode::FAILURE
            }
        },
        Err(error) => {
            eprintln!("cannot start test driver: {error}");
            ExitCode::FAILURE
        }
    }
}
